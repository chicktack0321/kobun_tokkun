import Foundation
import SwiftData

/// 文法の4択問題。同梱JSONで配布する問題バンク。
///
/// 単語クイズは「他の語の意味」を誤選択肢に流用できるが、文法は自動生成すると
/// 「接続を問う問題に意味の選択肢が並ぶ」ような成立しない問題になる。
/// 誤選択肢の質が学習効果そのものなので、問題ごと手で作って同梱する。
@Model
final class GrammarQuizItem {
    /// 例: "KOBUN_GQ_JODOSHI_RU_01"。**公開後の改名は禁止**（進捗のキー）
    @Attribute(.unique) var quizId: String

    /// 出題元の文法項目。結果画面から解説カードへ飛ぶのに使う
    var grammarId: String

    var question: String

    /// 4つの選択肢。SwiftData は Codable な配列をそのまま保存できる。
    /// 正解の位置は `answerIndex` で固定する（文字列一致で探すと同じ文言が複数あったとき誤判定する）。
    var choices: [String]
    var answerIndex: Int

    var explanation: String

    /// 紐づく文法項目の `isFree` をビルドスクリプトが伝播させる。
    /// 解説が無料なのに問題が有料（またはその逆）だと、学習の途中で不自然に途切れる。
    var isFree: Bool

    var updatedAt: Date

    init(
        quizId: String,
        grammarId: String,
        question: String,
        choices: [String],
        answerIndex: Int,
        explanation: String = "",
        isFree: Bool = false,
        updatedAt: Date = .now
    ) {
        self.quizId = quizId
        self.grammarId = grammarId
        self.question = question
        self.choices = choices
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.isFree = isFree
        self.updatedAt = updatedAt
    }

    /// 正解の選択肢。データが壊れていても落とさない（同梱JSONの破損で起動不能にしない方針）
    var correctChoice: String {
        guard choices.indices.contains(answerIndex) else { return "" }
        return choices[answerIndex]
    }
}
