import Foundation
import SwiftData

/// 古典文法の項目（助動詞「る・らる」、係助詞「ぞ」など）。1項目 = 1カード。
///
/// `WordMaster` と同じく Read-Only 想定で、同梱JSONからUpsertされる。
/// 文法項目そのものには進捗を持たせない。習熟度は紐づく `GrammarQuizItem` の
/// 進捗から導出する（`GrammarMastery`）。理由は「文法を覚えたか」は解説を読んだ回数ではなく
/// 問題に答えられるかで決まるため。
@Model
final class GrammarMaster {
    /// 例: "KOBUN_G_JODOSHI_RU"。**公開後の改名は禁止**
    @Attribute(.unique) var grammarId: String

    /// 見出し（例: "る・らる"）
    var title: String

    var categoryRaw: String

    /// 意味・用法の要約（例: "受身・可能・自発・尊敬"）
    var meaning: String

    /// 接続（例: "未然形"）。該当しない項目は空文字
    var connection: String

    /// 活用（例: "れ / れ / る / るる / るれ / れよ（下二段型）"）。該当しない項目は空文字
    var conjugation: String

    /// 解説。意味の見分け方など、暗記だけでは埋まらない部分を書く
    var explanation: String

    var example: String
    var exampleTranslation: String
    var source: String

    var isFree: Bool

    /// 表示順。五十音ではなく文法書の慣例順（助動詞なら接続順）に並べるため、データ側で明示する
    var sortOrder: Int

    var updatedAt: Date

    init(
        grammarId: String,
        title: String,
        category: GrammarCategory,
        meaning: String,
        connection: String = "",
        conjugation: String = "",
        explanation: String = "",
        example: String = "",
        exampleTranslation: String = "",
        source: String = "",
        isFree: Bool = false,
        sortOrder: Int = 0,
        updatedAt: Date = .now
    ) {
        self.grammarId = grammarId
        self.title = title
        self.categoryRaw = category.rawValue
        self.meaning = meaning
        self.connection = connection
        self.conjugation = conjugation
        self.explanation = explanation
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.source = source
        self.isFree = isFree
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
    }

    var category: GrammarCategory {
        get { GrammarCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
