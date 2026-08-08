import Foundation

/// 古文単語の品詞。
///
/// 参考元（英単語アプリ）の PartOfSpeech とは分類が違う。古文では活用の型が
/// 意味の理解に直結するため、形容動詞とナ変・ラ変を含む動詞をまとめず品詞として並べる。
enum KobunPartOfSpeech: String, Codable, CaseIterable, Identifiable {
    case verb
    case adjective       // 形容詞（ク活用・シク活用）
    case adjectiveVerb   // 形容動詞（ナリ活用・タリ活用）
    case noun
    case adverb
    case phrase          // 連語（「さらなり」「いふかひなし」など複数語の見出し）
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verb: return "動詞"
        case .adjective: return "形容詞"
        case .adjectiveVerb: return "形容動詞"
        case .noun: return "名詞"
        case .adverb: return "副詞"
        case .phrase: return "連語"
        case .other: return "その他"
        }
    }
}

/// 文法項目の分類。単語帳の文法タブでセクション見出しとして使う。
///
/// 表示順は `sortOrder`（データ側で指定）で決めるが、セクションの並びはこの enum の
/// 宣言順に従う。文法書の慣例（助動詞 → 助詞 → 敬語 → 識別）に合わせている。
enum GrammarCategory: String, Codable, CaseIterable, Identifiable {
    case auxiliaryVerb   // 助動詞
    case particle        // 助詞
    case honorific       // 敬語
    case other           // 識別・係り結び・音便など

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auxiliaryVerb: return "助動詞"
        case .particle: return "助詞"
        case .honorific: return "敬語"
        case .other: return "識別・その他"
        }
    }

    var summary: String {
        switch self {
        case .auxiliaryVerb: return "接続と活用で見分ける。読解の得点源"
        case .particle: return "係助詞・接続助詞・副助詞。文の構造を決める"
        case .honorific: return "敬意の方向から主語を判別する"
        case .other: return "「なり」「に」「ぬ」の識別、係り結び、音便"
        }
    }
}

/// 学習項目の種別。単語と文法で進捗の集計を分けるために使う。
enum StudyDomain: String, Codable, CaseIterable, Identifiable {
    case word
    case grammar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .word: return "単語"
        case .grammar: return "文法"
        }
    }
}

/// 項目ごとの習熟段階。
///
/// 直近の正誤で反転させるのではなく、間隔反復の習得段階（`ItemProgress.reviewBox`）から導く。
/// 1回正解しただけで「覚えた」にしてしまうと、実際には翌日忘れている項目まで覚えた扱いになり、
/// 習熟度の表示が学習の実態と乖離して意味を失うため。
enum LearningStatus: String, Codable, CaseIterable, Identifiable {
    /// 一度も出題していない
    case notStudied
    /// 直近で間違えた、または復習期限が過ぎている
    case needsReview
    /// 正解を重ねている途中（復習間隔は1〜3日）
    case learning
    /// 1週間以上の間隔を空けても正解できた
    case memorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStudied: return "未学習"
        case .needsReview: return "要復習"
        case .learning: return "学習中"
        case .memorized: return "覚えた"
        }
    }

    /// この段階に到達する条件。画面上の「iマーク」でそのまま見せる。
    var criteria: String {
        switch self {
        case .notStudied: return "まだ一度も出題されていない項目です。"
        case .needsReview: return "直近で間違えたか、復習の期限が来ている項目です。優先して出題されます。"
        case .learning: return "正解を重ねている途中の項目です。1〜3日の間隔で再出題されます。"
        case .memorized: return "1週間以上あけても正解できた項目です。以後は間隔を広げて確認します。"
        }
    }

    /// 単語帳・習熟度バー・凡例で同じ見た目にするため、記号は段階自身に持たせる
    var symbolName: String {
        switch self {
        case .notStudied: return "circle"
        case .needsReview: return "exclamationmark.circle.fill"
        case .learning: return "arrow.triangle.2.circlepath.circle.fill"
        case .memorized: return "checkmark.circle.fill"
        }
    }
}
