import Foundation
import SwiftData

/// 単語・文法・文法問題の読み出しを集約する層。
///
/// 参考元は階層・分野・頻出度と購入状況の組み合わせで出題母集団を絞っていたが、
/// 本アプリは完全無料で階層も持たないため、出題対象は常に全項目になる。
/// 絞り込みは画面側の習熟度フィルタだけが行う。
@MainActor
struct ContentRepository {
    let context: ModelContext

    // MARK: - 単語

    /// 全語。並びは五十音順。
    /// 歴史的仮名遣いの `word` で並べると辞書の並びとずれるため `reading` を使う。
    func allWords() -> [WordMaster] {
        let descriptor = FetchDescriptor<WordMaster>(sortBy: [SortDescriptor(\.reading)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func word(id: String) -> WordMaster? {
        let descriptor = FetchDescriptor<WordMaster>(predicate: #Predicate { $0.wordId == id })
        return try? context.fetch(descriptor).first
    }

    func wordCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<WordMaster>())) ?? 0
    }

    // MARK: - 文法

    /// 文法項目の全件。並びは文法書の慣例順（データ側の `sortOrder`）。
    func allGrammar() -> [GrammarMaster] {
        let descriptor = FetchDescriptor<GrammarMaster>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func grammar(id: String) -> GrammarMaster? {
        let descriptor = FetchDescriptor<GrammarMaster>(predicate: #Predicate { $0.grammarId == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: - 文法問題

    func allGrammarQuiz() -> [GrammarQuizItem] {
        (try? context.fetch(FetchDescriptor<GrammarQuizItem>())) ?? []
    }

    /// 特定の文法項目に紐づく問題（文法詳細の「この項目の問題を解く」用）
    func grammarQuiz(forGrammarId grammarId: String) -> [GrammarQuizItem] {
        let descriptor = FetchDescriptor<GrammarQuizItem>(
            predicate: #Predicate { $0.grammarId == grammarId }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func grammarQuizCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<GrammarQuizItem>())) ?? 0
    }
}
