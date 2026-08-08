import XCTest
@testable import KobunApp

/// 文法項目の習熟度の導出テスト。
///
/// 集約の規則を間違えても画面上は「それらしい」表示になり、誤りに気づけない。
/// 特に「4問中3問できるから覚えた」と出してしまうと、本番で落とす1問を隠すことになる。
final class GrammarMasteryTests: XCTestCase {

    func testNoQuestionsIsNotStudied() {
        XCTAssertEqual(GrammarMastery.status(ofQuizStatuses: []), .notStudied,
                       "解説だけの項目は未学習のままにする")
    }

    func testAllUnansweredIsNotStudied() {
        XCTAssertEqual(GrammarMastery.status(ofQuizStatuses: [.notStudied, .notStudied]), .notStudied)
    }

    func testAnyNeedsReviewWins() {
        XCTAssertEqual(
            GrammarMastery.status(ofQuizStatuses: [.memorized, .memorized, .needsReview]),
            .needsReview,
            "1問でも忘れていれば要復習。多数決にしない"
        )
    }

    func testAllMemorizedIsMemorized() {
        XCTAssertEqual(
            GrammarMastery.status(ofQuizStatuses: [.memorized, .memorized]),
            .memorized
        )
    }

    func testPartiallyMemorizedIsLearning() {
        XCTAssertEqual(
            GrammarMastery.status(ofQuizStatuses: [.memorized, .learning]),
            .learning,
            "全問が覚えた段階に達するまでは覚えた扱いにしない"
        )
    }

    func testMixOfUnstudiedAndMemorizedIsLearning() {
        XCTAssertEqual(
            GrammarMastery.status(ofQuizStatuses: [.memorized, .notStudied]),
            .learning,
            "まだ解いていない問題が残っている項目を『覚えた』にしない"
        )
    }

    func testStatusByGrammarIdIncludesItemsWithoutQuestions() {
        let table = GrammarMastery.statusByGrammarId(
            quizItems: [],
            progress: [:],
            grammarIds: ["KOBUN_G_A", "KOBUN_G_B"]
        )

        XCTAssertEqual(table.count, 2, "問題を持たない項目も表に載せる（一覧で欠落させない）")
        XCTAssertEqual(table["KOBUN_G_A"], .notStudied)
    }

    func testStatusByGrammarIdGroupsByGrammarId() {
        let now = Date()
        let quizItems = [
            GrammarQuizItem(quizId: "Q1", grammarId: "G_A", question: "", choices: ["1", "2", "3", "4"], answerIndex: 0),
            GrammarQuizItem(quizId: "Q2", grammarId: "G_A", question: "", choices: ["1", "2", "3", "4"], answerIndex: 0),
            GrammarQuizItem(quizId: "Q3", grammarId: "G_B", question: "", choices: ["1", "2", "3", "4"], answerIndex: 0)
        ]

        // Q1/Q2 は覚えた、Q3 は未学習
        let memorized = ItemProgress(itemId: "Q1", attemptCount: 1, reviewBox: ItemProgress.masteredBox)
        memorized.nextReviewAt = now.addingTimeInterval(86_400)
        let memorized2 = ItemProgress(itemId: "Q2", attemptCount: 1, reviewBox: ItemProgress.masteredBox)
        memorized2.nextReviewAt = now.addingTimeInterval(86_400)

        let table = GrammarMastery.statusByGrammarId(
            quizItems: quizItems,
            progress: ["Q1": memorized, "Q2": memorized2],
            grammarIds: ["G_A", "G_B"],
            at: now
        )

        XCTAssertEqual(table["G_A"], .memorized)
        XCTAssertEqual(table["G_B"], .notStudied)
    }
}
