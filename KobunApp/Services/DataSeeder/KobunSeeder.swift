import Foundation
import SwiftData

/// JSONデコード用のDTO。SwiftDataの `@Model` と分離しておくことで、
/// 配布フォーマット（JSON/将来的にはsqlite同梱など）を自由に差し替えられるようにする。
private struct KobunSeedFile: Decodable {
    let version: Int
    let words: [WordSeedEntry]
    let grammar: [GrammarSeedEntry]
    let grammarQuiz: [GrammarQuizSeedEntry]
}

private struct WordSeedEntry: Decodable {
    let wordId: String
    let word: String
    let reading: String
    let meaning: String
    let partOfSpeech: String
    let example: String
    let exampleTranslation: String
    let source: String?
}

private struct GrammarSeedEntry: Decodable {
    let grammarId: String
    let title: String
    let category: String
    let meaning: String
    let connection: String?
    let conjugation: String?
    let explanation: String
    let example: String
    let exampleTranslation: String
    let source: String?
    let sortOrder: Int
}

private struct GrammarQuizSeedEntry: Decodable {
    let quizId: String
    let grammarId: String
    let question: String
    let choices: [String]
    let answerIndex: Int
    let explanation: String
}

enum KobunSeederError: Error {
    case seedFileNotFound
    case decodeFailed(Error)
}

/// アプリ起動時にマスターデータ（単語・文法・文法問題）を最新へUpsertしつつ、
/// 学習履歴（`ItemProgress`）には一切手を触れずに保持するための初期化処理。
@MainActor
enum KobunSeeder {
    /// UserDefaults に保存する、直近で適用した seed のバージョン番号
    private static let appliedVersionKey = "kobunSeedVersion"

    /// アプリ起動時に一度だけ呼び出す。バンドル同梱JSONのバージョンが
    /// 既適用バージョンより新しい場合のみ Upsert を実行する（毎起動フルスキャンを避ける）。
    static func seedIfNeeded(context: ModelContext, bundle: Bundle = .main) throws {
        let seedFile = try loadSeedFile(bundle: bundle)

        let appliedVersion = UserDefaults.standard.integer(forKey: appliedVersionKey)
        // 適用済みバージョンは UserDefaults、実データは SwiftData と保存先が分かれているため、
        // 両者が食い違うことがある（ストアの作り直し、バックアップからの復元など）。
        // データが1件も無ければバージョンに関わらず作り直して、空のまま復旧しない状態を防ぐ。
        let storeIsEmpty = ((try? context.fetchCount(FetchDescriptor<WordMaster>())) ?? 0) == 0
        guard seedFile.version > appliedVersion || storeIsEmpty else { return }

        do {
            try upsertWords(seedFile.words, context: context)
            try upsertGrammar(seedFile.grammar, context: context)
            try upsertGrammarQuiz(seedFile.grammarQuiz, context: context)
            try context.save()
        } catch {
            // 中途半端に適用された変更を残すと次回以降の判定が狂うため、破棄してから投げ直す
            context.rollback()
            throw error
        }

        // 保存が成功して初めてバージョンを記録する。
        // 逆順にすると save 失敗時に「バージョンだけ進んでデータが空」の状態が永続化され、
        // 以降シードがスキップされて二度と復旧しなくなる。
        UserDefaults.standard.set(seedFile.version, forKey: appliedVersionKey)
    }

    private static func loadSeedFile(bundle: Bundle) throws -> KobunSeedFile {
        guard let url = bundle.url(forResource: AppConfig.seedResourceName, withExtension: "json") else {
            throw KobunSeederError.seedFileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KobunSeedFile.self, from: data)
        } catch {
            throw KobunSeederError.decodeFailed(error)
        }
    }

    // MARK: - Upsert
    //
    // 3テーブルとも同じ手順を踏む: 既存行をIDで索引化 → 既知は上書き・未知は追加 →
    // JSONから消えた行は削除。進捗（ItemProgress）には触れないため、
    // 削除された項目の進捗は孤児として残るが、画面はマスターが在る行しか表示しないので実害はない。
    // 参考元と違いユーザー追加項目の機能が無いので、出所（source）の区別は不要。

    private static func upsertWords(_ entries: [WordSeedEntry], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<WordMaster>())
        var existingById = Dictionary(existing.map { ($0.wordId, $0) }, uniquingKeysWith: { first, _ in first })

        for entry in entries {
            // 未知の品詞は落とさず .other に寄せる。1語のtypoで語全体が消えるほうが損害が大きい
            let partOfSpeech = KobunPartOfSpeech(rawValue: entry.partOfSpeech) ?? .other

            if let word = existingById.removeValue(forKey: entry.wordId) {
                word.word = entry.word
                word.reading = entry.reading
                word.meaning = entry.meaning
                word.partOfSpeech = partOfSpeech
                word.example = entry.example
                word.exampleTranslation = entry.exampleTranslation
                word.source = entry.source ?? ""
                word.updatedAt = .now
            } else {
                context.insert(WordMaster(
                    wordId: entry.wordId,
                    word: entry.word,
                    reading: entry.reading,
                    meaning: entry.meaning,
                    partOfSpeech: partOfSpeech,
                    example: entry.example,
                    exampleTranslation: entry.exampleTranslation,
                    source: entry.source ?? ""
                ))
            }
        }

        for orphan in existingById.values {
            context.delete(orphan)
        }
    }

    private static func upsertGrammar(_ entries: [GrammarSeedEntry], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<GrammarMaster>())
        var existingById = Dictionary(existing.map { ($0.grammarId, $0) }, uniquingKeysWith: { first, _ in first })

        for entry in entries {
            let category = GrammarCategory(rawValue: entry.category) ?? .other

            if let grammar = existingById.removeValue(forKey: entry.grammarId) {
                grammar.title = entry.title
                grammar.category = category
                grammar.meaning = entry.meaning
                grammar.connection = entry.connection ?? ""
                grammar.conjugation = entry.conjugation ?? ""
                grammar.explanation = entry.explanation
                grammar.example = entry.example
                grammar.exampleTranslation = entry.exampleTranslation
                grammar.source = entry.source ?? ""
                grammar.sortOrder = entry.sortOrder
                grammar.updatedAt = .now
            } else {
                context.insert(GrammarMaster(
                    grammarId: entry.grammarId,
                    title: entry.title,
                    category: category,
                    meaning: entry.meaning,
                    connection: entry.connection ?? "",
                    conjugation: entry.conjugation ?? "",
                    explanation: entry.explanation,
                    example: entry.example,
                    exampleTranslation: entry.exampleTranslation,
                    source: entry.source ?? "",
                    sortOrder: entry.sortOrder
                ))
            }
        }

        for orphan in existingById.values {
            context.delete(orphan)
        }
    }

    private static func upsertGrammarQuiz(_ entries: [GrammarQuizSeedEntry], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<GrammarQuizItem>())
        var existingById = Dictionary(existing.map { ($0.quizId, $0) }, uniquingKeysWith: { first, _ in first })

        for entry in entries {
            // 選択肢の数と正解位置が壊れた問題は入れない。出題時に落ちるより
            // 「その問題だけ出ない」ほうが被害が小さい（ビルド時にも scripts/build_seed.py が弾く）
            guard entry.choices.count == 4, entry.choices.indices.contains(entry.answerIndex) else { continue }

            if let quiz = existingById.removeValue(forKey: entry.quizId) {
                quiz.grammarId = entry.grammarId
                quiz.question = entry.question
                quiz.choices = entry.choices
                quiz.answerIndex = entry.answerIndex
                quiz.explanation = entry.explanation
                quiz.updatedAt = .now
            } else {
                context.insert(GrammarQuizItem(
                    quizId: entry.quizId,
                    grammarId: entry.grammarId,
                    question: entry.question,
                    choices: entry.choices,
                    answerIndex: entry.answerIndex,
                    explanation: entry.explanation
                ))
            }
        }

        for orphan in existingById.values {
            context.delete(orphan)
        }
    }
}

// 進捗行（ItemProgress）はここでは作らない。
// 一度も使わない空の行を項目数だけ作ることになり、初回起動と各画面の集計がそのぶん重くなる。
// 行は最初に解答した時点で `ProgressRepository.progress(for:)` が作る。
// 「未学習」の数は行の有無ではなく、全項目数から学習済みの数を引いて求める。
