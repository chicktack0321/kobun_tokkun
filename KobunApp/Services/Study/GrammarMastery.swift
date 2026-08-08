import Foundation

/// 文法項目の習熟度を、その項目に紐づく問題群の進捗から導く。
///
/// 文法項目そのものには進捗を持たせていない（`GrammarMaster` にコメントあり）。
/// 「助動詞『る・らる』を覚えたか」は解説カードを開いた回数ではなく、
/// その項目の問題に答えられるかで決まるため、判断の根拠を問題側の進捗に一本化している。
///
/// SwiftDataに触れない純粋関数にしてユニットテストする。集約の規則を間違えても
/// 画面上は「それらしい」表示になり、誤りに気づけないため。
enum GrammarMastery {

    /// 問題群のステータスから文法項目1件のステータスを決める。
    ///
    /// 規則（厳しい側に倒す）:
    /// - 問題が1問も無い項目は `.notStudied`（解説だけの項目）
    /// - 1問も解いていなければ `.notStudied`
    /// - 1問でも要復習があれば `.needsReview` — 部分的に忘れている状態を「覚えた」に含めない
    /// - 全問が覚えた段階なら `.memorized`
    /// - それ以外は `.learning`
    ///
    /// 多数決や平均にしないのは、「4問中3問できるから覚えた」と表示された項目が
    /// 試験本番で落とす1問を隠してしまうため。
    static func status(ofQuizStatuses statuses: [LearningStatus]) -> LearningStatus {
        guard !statuses.isEmpty else { return .notStudied }
        if statuses.allSatisfy({ $0 == .notStudied }) { return .notStudied }
        if statuses.contains(.needsReview) { return .needsReview }
        if statuses.allSatisfy({ $0 == .memorized }) { return .memorized }
        return .learning
    }

    /// 文法項目ID → ステータスの対応表を作る。
    ///
    /// - Parameters:
    ///   - quizItems: 全文法問題
    ///   - progress: `ItemProgress` を itemId で引ける辞書
    ///   - grammarIds: 問題を1問も持たない項目も表に載せるための全項目ID
    static func statusByGrammarId(
        quizItems: [GrammarQuizItem],
        progress: [String: ItemProgress],
        grammarIds: [String],
        at date: Date = .now
    ) -> [String: LearningStatus] {
        var statusesByGrammarId: [String: [LearningStatus]] = [:]
        for quiz in quizItems {
            let status = progress[quiz.quizId]?.status(at: date) ?? .notStudied
            statusesByGrammarId[quiz.grammarId, default: []].append(status)
        }

        var result: [String: LearningStatus] = [:]
        for grammarId in grammarIds {
            result[grammarId] = status(ofQuizStatuses: statusesByGrammarId[grammarId] ?? [])
        }
        return result
    }
}
