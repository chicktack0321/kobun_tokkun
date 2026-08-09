import Foundation
import SwiftData

/// 古文単語のマスターデータ。アプリ更新時に同梱JSONで丸ごとUpsertされる Read-Only 想定のテーブル。
///
/// `ItemProgress` とは `wordId` (String) でのみ緩く結びつけ、SwiftDataの `@Relationship` は張らない。
/// 理由: リレーションを張ると WordMaster の delete/upsert 時に ItemProgress へカスケードが波及するリスクがあるため、
/// 「マスターは総入れ替え、学習履歴は絶対保持」という要件上、意図的に疎結合にしている。
@Model
final class WordMaster {
    /// アプリ内で一意なID（例: "KOBUN_W_AHARENARI"）。JSON側の主キーと一致させる。
    /// **公開後の改名は禁止**（進捗がこのIDキーのため、改名は全ユーザーの学習履歴の消失になる）。
    @Attribute(.unique) var wordId: String

    /// 見出し語。歴史的仮名遣いで表記する（例: "あはれなり"）
    var word: String

    /// 現代仮名遣いの読み（例: "あわれなり"）。
    ///
    /// 表示は `word` だが、次の3つはすべて `reading` を使う:
    /// 1. TTS読み上げ — 「あはれ」をそのまま読ませると「あはれ」と綴り字通りに誤読される
    /// 2. 五十音順ソート — 歴史的仮名遣いで並べると辞書の並びとずれる
    /// 3. 検索 — 利用者は現代仮名遣いで入力する
    var reading: String

    var meaning: String

    var partOfSpeechRaw: String

    /// 古文の例文（原文）。古典なので著作権上の制約なく同梱できる
    var example: String
    var exampleTranslation: String

    /// 出典（例: "枕草子"）。不明・作例の場合は空文字
    var source: String

    /// マスターデータの更新検知用
    var updatedAt: Date

    init(
        wordId: String,
        word: String,
        reading: String,
        meaning: String,
        partOfSpeech: KobunPartOfSpeech,
        example: String = "",
        exampleTranslation: String = "",
        source: String = "",
        updatedAt: Date = .now
    ) {
        self.wordId = wordId
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.partOfSpeechRaw = partOfSpeech.rawValue
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.source = source
        self.updatedAt = updatedAt
    }

    var partOfSpeech: KobunPartOfSpeech {
        get { KobunPartOfSpeech(rawValue: partOfSpeechRaw) ?? .other }
        set { partOfSpeechRaw = newValue.rawValue }
    }

    /// 見出し語と読みが同じなら読みの併記は不要（「あき」など漢字を当てない語）
    var needsReadingAnnotation: Bool { word != reading }
}
