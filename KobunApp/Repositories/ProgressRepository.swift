import Foundation
import SwiftData

/// `ItemProgress` / `StudyLog` への読み書きを集約する層
@MainActor
struct ProgressRepository {
    let context: ModelContext

    func progress(for itemId: String) -> ItemProgress {
        let descriptor = FetchDescriptor<ItemProgress>(predicate: #Predicate { $0.itemId == itemId })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = ItemProgress(itemId: itemId)
        context.insert(created)
        return created
    }

    func allProgress() -> [String: ItemProgress] {
        let all = (try? context.fetch(FetchDescriptor<ItemProgress>())) ?? []
        return Dictionary(all.map { ($0.itemId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 1問の採点結果。呼び出し側が「覚えた」への到達を数えるのに使う
    struct AnswerOutcome {
        let wasMemorized: Bool
        let isMemorized: Bool

        var reachedMemorized: Bool { !wasMemorized && isMemorized }
    }

    /// 1問分の採点結果を `ItemProgress` と当日の `StudyLog` の両方に反映する。
    ///
    /// ここは解答のたびに通る道なので、項目数ぶんの走査を持ち込まないこと。
    /// 当日の習熟度の基準値はセッション開始時に `refreshMasterySnapshot` で作り、
    /// ここでは増減ぶんだけを足し引きする。
    ///
    /// - Parameter domain: 単語か文法か。習熟度のスナップショットを2系列に分けて持つのに使う。
    @discardableResult
    func recordAnswer(
        itemId: String,
        domain: StudyDomain,
        isCorrect: Bool,
        at date: Date = .now
    ) -> AnswerOutcome {
        let p = progress(for: itemId)
        let wasMemorized = p.status(at: date) == .memorized
        p.record(isCorrect: isCorrect, reviewedAt: date)
        let isMemorized = p.status(at: date) == .memorized

        let log = studyLog(for: date)
        log.attemptCount += 1
        log.studiedItemCount += 1
        if isCorrect { log.correctCount += 1 }

        // 習熟度は現在の状態しか残らないので、その日の最新値を残しておく。
        // でないと推移グラフを後から描けない。増減はこの項目が境目をまたいだときだけ起きる。
        if wasMemorized != isMemorized {
            let delta = isMemorized ? 1 : -1
            switch domain {
            case .word:
                log.masteredWordCount = max(0, log.masteredWordCount + delta)
            case .grammar:
                log.masteredGrammarCount = max(0, log.masteredGrammarCount + delta)
            }
        }

        // ここでは保存しない。1問ごとの save はそれ自体が待ち時間になる。
        // mainContext の自動保存に任せ、区切りで `save()` を呼ぶ。
        return AnswerOutcome(wasMemorized: wasMemorized, isMemorized: isMemorized)
    }

    /// 当日の「覚えた」数を数え直して焼き直す。
    ///
    /// 全項目を走査するので、解答中には呼ばないこと。想定している呼び出し元は
    /// セッションの開始時、単語詳細で「覚えた」「やり直す」を押したとき、学習の記録を開いたとき。
    /// 日付をまたいで復習期限が来た項目や、解答を経ない状態変更はここで拾う。
    func refreshMasterySnapshot(at date: Date = .now) {
        let snapshot = masteredSnapshot(at: date)
        let log = studyLog(for: date)
        log.masteredWordCount = snapshot.words
        log.masteredGrammarCount = snapshot.grammar
    }

    /// 区切りでの保存。解答ごとには呼ばない
    func save() {
        try? context.save()
    }

    struct MasterySnapshot {
        var words: Int
        var grammar: Int
    }

    /// 指定時点で「覚えた」段階にある数。
    ///
    /// マスターに実在する項目だけを数える。マスターを入れ替えても `ItemProgress` は
    /// 残す設計（`KobunSeeder` 参照）なので、進捗の行を全部数えると、
    /// データの更新で消えた項目まで「覚えた」に含まれ、単語帳やホームの表示と数が合わなくなる。
    func masteredSnapshot(at date: Date = .now) -> MasterySnapshot {
        let content = ContentRepository(context: context)
        let byId = allProgress()

        // count(where:) は Swift 6 で入った API なので、5.x でも通る filter().count で書く
        let words = content.allWords().filter { byId[$0.wordId]?.status(at: date) == .memorized }.count
        let grammar = content.allGrammarQuiz().filter { byId[$0.quizId]?.status(at: date) == .memorized }.count
        return MasterySnapshot(words: words, grammar: grammar)
    }

    private func studyLog(for date: Date) -> StudyLog {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<StudyLog>(predicate: #Predicate { $0.date == day })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = StudyLog(date: day)
        context.insert(created)
        return created
    }

    /// 直近 `days` 日分の日次ログを取得する。
    /// 全期間を読むと記録が増えるほど重くなるため、グラフに映る範囲だけを日付で絞る。
    func recentLogs(days: Int, endingOn today: Date = .now, calendar: Calendar = .current) -> [StudyLog] {
        let endDay = calendar.startOfDay(for: today)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else { return [] }

        let descriptor = FetchDescriptor<StudyLog>(
            predicate: #Predicate { $0.date >= startDay },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 連続学習日数の判定用。途切れを跨いで数えないよう、直近1年分あれば足りる。
    func logsForStreak(today: Date = .now, calendar: Calendar = .current) -> [StudyLog] {
        recentLogs(days: 366, endingOn: today, calendar: calendar)
    }

    /// 当日分の `StudyLog`（未学習日は nil。record時のように新規作成はしない）
    func todayLog(date: Date = .now) -> StudyLog? {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<StudyLog>(predicate: #Predicate { $0.date == day })
        return try? context.fetch(descriptor).first
    }

    /// 指定したIDの集合について、ステータス内訳と累計正答率をまとめて返す。
    ///
    /// 進捗の行は「一度でも解いた項目」にしか無いので、行の側からではなく項目の側から引く。
    /// 未学習は「全項目数 − 行がある項目数」で数える（行が無い＝未学習）。
    func summarize(itemIds: [String]) -> ProgressSummary {
        let byId = allProgress()
        var statusCounts: [LearningStatus: Int] = Dictionary(
            uniqueKeysWithValues: LearningStatus.allCases.map { ($0, 0) }
        )
        var totalCorrect = 0
        var totalAttempts = 0

        for id in itemIds {
            guard let progress = byId[id] else {
                statusCounts[.notStudied, default: 0] += 1
                continue
            }
            statusCounts[progress.status, default: 0] += 1
            totalCorrect += progress.correctCount
            totalAttempts += progress.attemptCount
        }

        return ProgressSummary(
            statusCounts: statusCounts,
            totalCorrect: totalCorrect,
            totalAttempts: totalAttempts,
            total: itemIds.count
        )
    }
}

/// `ItemProgress` を1回走査して得られる集計値
struct ProgressSummary {
    var statusCounts: [LearningStatus: Int]
    var totalCorrect: Int
    var totalAttempts: Int
    var total: Int

    static let empty = ProgressSummary(statusCounts: [:], totalCorrect: 0, totalAttempts: 0, total: 0)

    func count(of status: LearningStatus) -> Int {
        statusCounts[status] ?? 0
    }

    /// 出題されたことのある項目に対する累計正答率
    var accuracy: Double {
        totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }
}
