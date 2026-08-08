import Foundation
import SwiftData

/// 単語・文法・文法問題の読み出しを集約する層。
///
/// 参考元は階層・分野・頻出度の組み合わせで出題母集団を絞っていたが、本アプリに
/// 絞り込みの軸は無い。ここが担うのは「権利で出題対象を切ること」だけになる。
@MainActor
struct ContentRepository {
    let context: ModelContext

    // MARK: - 単語

    /// 単語帳に出す全語。閲覧は権利に関わらず常に全語できる。
    /// 並びは五十音順。歴史的仮名遣いの `word` で並べると辞書の並びとずれるため `reading` を使う。
    func allWords() -> [WordMaster] {
        let descriptor = FetchDescriptor<WordMaster>(sortBy: [SortDescriptor(\.reading)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// クイズ・聞き流しの母集団。権利が無ければ無料の語だけに絞る。
    ///
    /// 「閲覧できる範囲」と「出題される範囲」を別の関数にしているのは、
    /// 1つのフラグに混ぜると出題されない理由が権利なのか設定なのかを切り分けられず、
    /// 画面の案内も出し分けられなくなるため。
    func studyWords(rights: AccessRights) -> [WordMaster] {
        let all = allWords()
        guard !rights.hasFullAccess else { return all }
        return all.filter(\.isFree)
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

    /// クイズの母集団。権利が無ければ無料の問題だけに絞る。
    func studyGrammarQuiz(rights: AccessRights) -> [GrammarQuizItem] {
        let all = allGrammarQuiz()
        guard !rights.hasFullAccess else { return all }
        return all.filter(\.isFree)
    }

    /// 特定の文法項目に紐づく問題（文法詳細の「この項目の問題を解く」用）。
    /// ここでは権利で絞らない。呼び出し側が「解ける問題が無い」ことを案内できるようにするため。
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
