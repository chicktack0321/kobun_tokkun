import Foundation

/// 単語クイズの選択肢を組み立てる。
///
/// ViewModel から切り出しているのは、ここが「壊れても画面上は正常に見える」場所だから。
/// 正解と同じ文言がダミーに混ざると、正しい選択肢を選んでも不正解になる。
/// 選択肢が4つ揃わなくても画面は成立してしまう。どちらも実行して眺めるだけでは気づけない。
enum QuizChoiceBuilder {
    static let choiceCount = 4

    struct Choices {
        let options: [String]
        let correctIndex: Int
    }

    /// - Parameters:
    ///   - correctMeaning: 正解の訳
    ///   - samePartOfSpeech: 同じ品詞の候補の訳（優先して使う）
    ///   - others: 品詞を問わない候補の訳（同品詞で足りないときの補充）
    ///   - randomIndex: 正解を挿入する位置の決め方。テストから固定するために差し込めるようにしている
    static func build(
        correctMeaning: String,
        samePartOfSpeech: [String],
        others: [String],
        randomIndex: (ClosedRange<Int>) -> Int = { Int.random(in: $0) }
    ) -> Choices {
        // 別々の語が同じ訳を持つことは珍しくない（「つらい」「気の毒だ」など）。
        // 重複を除いたうえでダミーを集める。
        var used: Set<String> = [correctMeaning]
        var distractors: [String] = []

        // 同じ品詞から選べると選択肢が締まる（品詞の違いだけで答えを絞れてしまうのを防ぐ）
        for candidate in samePartOfSpeech + others {
            guard distractors.count < choiceCount - 1 else { break }
            guard !used.contains(candidate) else { continue }
            used.insert(candidate)
            distractors.append(candidate)
        }

        // 正解の位置は挿入時に決めて保持する。あとから文字列検索で探すと、
        // 同じ文字列が複数あった場合に誤った位置を正解と見なしてしまう。
        let correctIndex = randomIndex(0...distractors.count)
        var options = distractors
        options.insert(correctMeaning, at: correctIndex)

        return Choices(options: options, correctIndex: correctIndex)
    }
}
