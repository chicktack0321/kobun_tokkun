import XCTest
@testable import KobunApp

/// 同梱データ（`kobun_seed.json`）そのものの検証。
///
/// `scripts/build_seed.py` でも同じ検証をしているが、生成し忘れ・手で直したあとの
/// 取り違えはスクリプトを通らない。アプリが実際に読むファイルを読んで確かめる。
/// データの不備は「その項目だけ静かに出題されない」形で現れ、実行しても気づけない。
final class SeedDataTests: XCTestCase {

    private struct SeedFile: Decodable {
        struct Word: Decodable {
            let wordId: String
            let word: String
            let reading: String
            let meaning: String
            let partOfSpeech: String
            let example: String
            let exampleTranslation: String
            let isFree: Bool
        }
        struct Grammar: Decodable {
            let grammarId: String
            let title: String
            let category: String
            let meaning: String
            let explanation: String
            let isFree: Bool
            let sortOrder: Int
        }
        struct Quiz: Decodable {
            let quizId: String
            let grammarId: String
            let question: String
            let choices: [String]
            let answerIndex: Int
            let explanation: String
            let isFree: Bool
        }
        let version: Int
        let words: [Word]
        let grammar: [Grammar]
        let grammarQuiz: [Quiz]
    }

    private var seed: SeedFile!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        // テストバンドルとアプリバンドルのどちらに入るかは設定で変わるため、両方を探す
        let url = try XCTUnwrap(
            bundle.url(forResource: AppConfig.seedResourceName, withExtension: "json")
                ?? Bundle.main.url(forResource: AppConfig.seedResourceName, withExtension: "json"),
            "同梱データ \(AppConfig.seedResourceName).json が見つかりません"
        )
        seed = try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: url))
    }

    func testSeedIsNotEmpty() {
        XCTAssertGreaterThan(seed.version, 0)
        XCTAssertGreaterThanOrEqual(seed.words.count, 300, "単語は300語以上を同梱する")
        XCTAssertFalse(seed.grammar.isEmpty)
        XCTAssertFalse(seed.grammarQuiz.isEmpty)
    }

    func testIdsAreUnique() {
        XCTAssertEqual(Set(seed.words.map(\.wordId)).count, seed.words.count, "wordId が重複している")
        XCTAssertEqual(Set(seed.grammar.map(\.grammarId)).count, seed.grammar.count, "grammarId が重複している")
        XCTAssertEqual(Set(seed.grammarQuiz.map(\.quizId)).count, seed.grammarQuiz.count, "quizId が重複している")
    }

    /// 読みが空だと聞き流しで歴史的仮名遣いのまま読まれ、実際の音と食い違う
    func testEveryWordHasReadingAndMeaning() {
        for word in seed.words {
            XCTAssertFalse(word.reading.isEmpty, "\(word.wordId): reading が空")
            XCTAssertFalse(word.meaning.isEmpty, "\(word.wordId): meaning が空")
            XCTAssertFalse(word.example.isEmpty, "\(word.wordId): example が空")
            XCTAssertFalse(word.exampleTranslation.isEmpty, "\(word.wordId): 例文の訳が空")
        }
    }

    func testPartOfSpeechValuesAreKnown() {
        for word in seed.words {
            XCTAssertNotNil(
                KobunPartOfSpeech(rawValue: word.partOfSpeech),
                "\(word.wordId): 未知の品詞 \(word.partOfSpeech)（Swift側では .other に落ちて気づけない）"
            )
        }
    }

    func testGrammarCategoriesAreKnownAndSortOrderIsUnique() {
        for item in seed.grammar {
            XCTAssertNotNil(
                GrammarCategory(rawValue: item.category),
                "\(item.grammarId): 未知のカテゴリ \(item.category)"
            )
            XCTAssertFalse(item.explanation.isEmpty, "\(item.grammarId): explanation が空")
        }
        let orders = seed.grammar.map(\.sortOrder)
        XCTAssertEqual(Set(orders).count, orders.count, "sortOrder が重複すると表示順が安定しない")
    }

    func testQuizChoicesAreWellFormed() {
        for quiz in seed.grammarQuiz {
            XCTAssertEqual(quiz.choices.count, 4, "\(quiz.quizId): 選択肢は4件でなければならない")
            XCTAssertEqual(Set(quiz.choices).count, quiz.choices.count,
                           "\(quiz.quizId): 同じ文言の選択肢があると、正解を選んでも不正解になりうる")
            XCTAssertTrue(quiz.choices.indices.contains(quiz.answerIndex),
                          "\(quiz.quizId): answerIndex が範囲外")
            XCTAssertFalse(quiz.explanation.isEmpty, "\(quiz.quizId): 解説が空")
        }
    }

    /// 正解が常に同じ位置にあると、内容を覚えなくても解けてしまう
    func testAnswerPositionsAreSpread() {
        let positions = Set(seed.grammarQuiz.map(\.answerIndex))
        XCTAssertEqual(positions.count, 4, "正解の位置が4通りに散っていない")
    }

    func testEveryQuizReferencesAnExistingGrammarItem() {
        let grammarIds = Set(seed.grammar.map(\.grammarId))
        for quiz in seed.grammarQuiz {
            XCTAssertTrue(grammarIds.contains(quiz.grammarId),
                          "\(quiz.quizId): 参照先の文法項目 \(quiz.grammarId) が無い")
        }
    }

    /// 解説が無料なのに問題が有料（またはその逆）だと、学習が途中で不自然に途切れる
    func testQuizFreeFlagMatchesItsGrammarItem() {
        let freeByGrammarId = Dictionary(
            seed.grammar.map { ($0.grammarId, $0.isFree) },
            uniquingKeysWith: { first, _ in first }
        )
        for quiz in seed.grammarQuiz {
            XCTAssertEqual(freeByGrammarId[quiz.grammarId], quiz.isFree,
                           "\(quiz.quizId): 無料/有料が文法項目と食い違っている")
        }
    }

    /// 未購入・試用終了後でも学習を続けられる分量が残っている必要がある
    func testFreeRangeIsUsable() {
        XCTAssertGreaterThanOrEqual(seed.words.filter(\.isFree).count, 100)
        XCTAssertGreaterThanOrEqual(seed.grammarQuiz.filter(\.isFree).count, 20)
    }
}
