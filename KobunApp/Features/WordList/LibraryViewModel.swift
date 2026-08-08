import Foundation
import SwiftData
import Observation

/// 単語帳タブの表示切り替え。文法を独立タブにせずここに入れている。
enum LibrarySegment: String, CaseIterable, Identifiable {
    case word
    case grammar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word: return "単語"
        case .grammar: return "文法"
        }
    }
}

/// 単語帳（単語・文法）の一覧を組み立てる。
///
/// 参考元は階層・分野・頻出度で絞り込めたが、本アプリの軸は
/// 「検索」と「習熟度」の2つだけ。絞り込みの選択肢を増やすより、
/// 一覧をすぐ引ける状態を保つことを優先している。
@Observable
@MainActor
final class LibraryViewModel {
    var segment: LibrarySegment = .word
    var searchText: String = ""
    /// nil は「すべて」
    var statusFilter: LearningStatus?

    private(set) var words: [WordMaster] = []
    private(set) var grammar: [GrammarMaster] = []
    /// 単語ID → 習熟段階
    private(set) var wordStatus: [String: LearningStatus] = [:]
    /// 文法項目ID → 習熟段階（紐づく問題群から導出したもの）
    private(set) var grammarStatus: [String: LearningStatus] = [:]
    /// 文法項目ID → 問題数。0問の項目は「問題を解く」ボタンを出さない
    private(set) var grammarQuizCounts: [String: Int] = [:]

    private var content: ContentRepository?
    private var progressRepository: ProgressRepository?

    func configure(context: ModelContext) {
        if content == nil {
            content = ContentRepository(context: context)
            progressRepository = ProgressRepository(context: context)
        }
        reload()
    }

    /// 画面が現れるたびに読み直す。クイズで進捗が動いたあと、
    /// 単語帳に戻ったときに古い習熟度が残っていると学習の実感が損なわれる。
    func reload() {
        guard let content, let progressRepository else { return }

        words = content.allWords()
        grammar = content.allGrammar()

        let progress = progressRepository.allProgress()
        wordStatus = words.reduce(into: [:]) { result, word in
            result[word.wordId] = progress[word.wordId]?.status ?? .notStudied
        }

        let quizItems = content.allGrammarQuiz()
        grammarStatus = GrammarMastery.statusByGrammarId(
            quizItems: quizItems,
            progress: progress,
            grammarIds: grammar.map(\.grammarId)
        )
        grammarQuizCounts = quizItems.reduce(into: [:]) { result, item in
            result[item.grammarId, default: 0] += 1
        }
    }

    // MARK: - 絞り込み

    var filteredWords: [WordMaster] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        return words.filter { word in
            if let statusFilter, wordStatus[word.wordId] != statusFilter { return false }
            guard !keyword.isEmpty else { return true }
            // 利用者は現代仮名遣いで入力するので、見出し語だけでなく読みも検索対象にする
            return word.word.contains(keyword)
                || word.reading.contains(keyword)
                || word.meaning.contains(keyword)
        }
    }

    /// カテゴリごとに区切った文法項目。セクションの並びは enum の宣言順（文法書の慣例）に従う。
    var filteredGrammarSections: [(category: GrammarCategory, items: [GrammarMaster])] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = grammar.filter { item in
            if let statusFilter, grammarStatus[item.grammarId] != statusFilter { return false }
            guard !keyword.isEmpty else { return true }
            return item.title.contains(keyword)
                || item.meaning.contains(keyword)
                || item.explanation.contains(keyword)
        }
        return GrammarCategory.allCases.compactMap { category in
            let items = filtered.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    /// 現在の絞り込みで何件見えているか（空表示の文言を出し分けるのに使う）
    var visibleCount: Int {
        segment == .word ? filteredWords.count : filteredGrammarSections.reduce(0) { $0 + $1.items.count }
    }

    var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || statusFilter != nil
    }

    // MARK: - 単語詳細からの操作

    /// 「覚えたことにする」「やり直す」。どちらも当日の習熟度スナップショットを取り直す
    /// （解答を経ない状態変更なので、ここで焼き直さないとホームの推移とずれる）。
    func updateStatus(itemId: String, to action: MasteryAction) {
        guard let progressRepository else { return }
        let progress = progressRepository.progress(for: itemId)
        switch action {
        case .memorized: progress.markAsMemorized()
        case .review: progress.markForReview()
        }
        progressRepository.refreshMasterySnapshot()
        progressRepository.save()
        reload()
    }

    enum MasteryAction {
        case memorized
        case review
    }

    func progress(for itemId: String) -> ItemProgress? {
        progressRepository?.allProgress()[itemId]
    }

    func quizItems(forGrammarId grammarId: String) -> [GrammarQuizItem] {
        content?.grammarQuiz(forGrammarId: grammarId) ?? []
    }
}
