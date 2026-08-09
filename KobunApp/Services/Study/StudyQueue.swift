import Foundation

/// 進捗を紐づけられる学習項目。単語と文法問題で同じ出題順ロジックを共有するための最小の約束。
protocol StudyItem {
    /// `ItemProgress.itemId` に対応するキー
    var studyItemId: String { get }
}

extension WordMaster: StudyItem {
    var studyItemId: String { wordId }
}

extension GrammarQuizItem: StudyItem {
    var studyItemId: String { quizId }
}

/// 出題順を決めるロジック。
///
/// このアプリの価値は「忘れかけた項目を適切なタイミングで再提示すること」にあるため、
/// 毎回ランダムに出すのではなく次の優先度で並べる:
///
/// 1. 復習期限が来ている項目（間違えた・間隔が満了した）
/// 2. まだ一度も解いていない項目
/// 3. まだ期限前の項目（期限が近い順）
///
/// SwiftDataのフェッチに触れない純粋関数にしてあるため、そのままユニットテストできる。
/// 単語（`WordMaster`）と文法問題（`GrammarQuizItem`）の両方に同じ関数を使う。
enum StudyQueue {
    static func prioritize<Item: StudyItem>(
        items: [Item],
        progress: [String: ItemProgress],
        now: Date = .now
    ) -> [Item] {
        var due: [Item] = []
        var unstudied: [Item] = []
        var scheduled: [(item: Item, dueDate: Date)] = []

        for item in items {
            guard let record = progress[item.studyItemId], record.attemptCount > 0 else {
                unstudied.append(item)
                continue
            }
            if let nextReviewAt = record.nextReviewAt {
                if nextReviewAt <= now {
                    due.append(item)
                } else {
                    scheduled.append((item, nextReviewAt))
                }
            } else {
                // 解いた記録はあるが日程が入っていないデータは復習対象として扱う
                due.append(item)
            }
        }

        // 同じ優先度の中では順番を固定したくないのでシャッフルする。
        // 期限前の項目だけは「期限が近い順」に意味があるため並びを保つ。
        due.shuffle()
        unstudied.shuffle()

        return due + unstudied + scheduled.sorted { $0.dueDate < $1.dueDate }.map(\.item)
    }

    /// 習熟段階で絞り込む。`status` が nil ならそのまま返す。
    ///
    /// 進捗の行は「一度でも解いた項目」にしか無いので、行が無い項目は未学習として扱う。
    /// 行の側から引くと未学習の項目が丸ごと抜け落ちる。
    static func filter<Item: StudyItem>(
        items: [Item],
        byStatus status: LearningStatus?,
        progress: [String: ItemProgress],
        now: Date = .now
    ) -> [Item] {
        guard let status else { return items }
        return items.filter { item in
            (progress[item.studyItemId]?.status(at: now) ?? .notStudied) == status
        }
    }

    /// 復習期限が来ている項目だけを返す。未学習は「復習」ではないので含めない。
    /// ホームの「復習する項目がN件あります」から始めるクイズは、ここで返る項目だけを出題する。
    static func dueItems<Item: StudyItem>(
        items: [Item],
        progress: [String: ItemProgress],
        now: Date = .now
    ) -> [Item] {
        items.filter { item in
            guard let record = progress[item.studyItemId], record.attemptCount > 0 else { return false }
            return record.isDue(at: now)
        }.shuffled()
    }

    /// 復習期限が来ている項目の件数（ホーム画面の「今日の復習」表示用）
    static func dueCount<Item: StudyItem>(
        items: [Item],
        progress: [String: ItemProgress],
        now: Date = .now
    ) -> Int {
        items.reduce(into: 0) { count, item in
            guard let record = progress[item.studyItemId], record.attemptCount > 0 else { return }
            if record.isDue(at: now) { count += 1 }
        }
    }
}
