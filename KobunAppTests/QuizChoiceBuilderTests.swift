import XCTest
@testable import KobunApp

/// 単語クイズの選択肢生成テスト。
///
/// 「正解と同じ文言がダミーに混ざる」「選択肢が4つ揃わない」はどちらも
/// 画面上は成立して見えるため、実行して眺めるだけでは気づけない。
final class QuizChoiceBuilderTests: XCTestCase {

    func testProducesFourUniqueChoices() {
        let result = QuizChoiceBuilder.build(
            correctMeaning: "しみじみと趣深い",
            samePartOfSpeech: ["退屈だ", "はかない", "つらい", "優美だ"],
            others: []
        )

        XCTAssertEqual(result.options.count, 4)
        XCTAssertEqual(Set(result.options).count, 4, "選択肢に重複があってはならない")
    }

    func testCorrectIndexPointsAtTheCorrectMeaning() {
        for _ in 0..<50 {
            let result = QuizChoiceBuilder.build(
                correctMeaning: "正解",
                samePartOfSpeech: ["A", "B", "C"],
                others: []
            )
            XCTAssertEqual(result.options[result.correctIndex], "正解")
        }
    }

    /// 別々の語が同じ訳を持つのは珍しくない。正解と同じ文言が混ざると、
    /// 正しい選択肢を選んでも位置が違えば不正解になってしまう
    func testDuplicateOfCorrectMeaningIsExcluded() {
        let result = QuizChoiceBuilder.build(
            correctMeaning: "つらい",
            samePartOfSpeech: ["つらい", "いやだ", "悲しい", "苦しい"],
            others: []
        )

        XCTAssertEqual(result.options.filter { $0 == "つらい" }.count, 1)
        XCTAssertEqual(result.options.count, 4)
    }

    func testDuplicatesAmongDistractorsAreExcluded() {
        let result = QuizChoiceBuilder.build(
            correctMeaning: "正解",
            samePartOfSpeech: ["A", "A", "A", "B", "C"],
            others: []
        )

        XCTAssertEqual(Set(result.options).count, result.options.count)
        XCTAssertEqual(result.options.count, 4)
    }

    func testFallsBackToOtherPartsOfSpeechWhenSamePartIsScarce() {
        let result = QuizChoiceBuilder.build(
            correctMeaning: "正解",
            samePartOfSpeech: ["同品詞1"],
            others: ["別品詞1", "別品詞2", "別品詞3"]
        )

        XCTAssertEqual(result.options.count, 4)
        XCTAssertTrue(result.options.contains("同品詞1"), "同じ品詞の候補を優先して使う")
    }

    /// 出題対象が極端に少ない場合（無料範囲がごく僅かなど）でも落ちてはいけない
    func testDegradesGracefullyWithTooFewCandidates() {
        let result = QuizChoiceBuilder.build(
            correctMeaning: "正解",
            samePartOfSpeech: ["A"],
            others: []
        )

        XCTAssertEqual(result.options.count, 2)
        XCTAssertEqual(result.options[result.correctIndex], "正解")
    }

    func testWorksWithNoDistractorsAtAll() {
        let result = QuizChoiceBuilder.build(correctMeaning: "正解", samePartOfSpeech: [], others: [])

        XCTAssertEqual(result.options, ["正解"])
        XCTAssertEqual(result.correctIndex, 0)
    }

    func testCorrectAnswerCanLandAtEveryPosition() {
        // 位置の決め方を差し込んで、どの位置に入れても整合することを確かめる
        for position in 0..<4 {
            let result = QuizChoiceBuilder.build(
                correctMeaning: "正解",
                samePartOfSpeech: ["A", "B", "C"],
                others: [],
                randomIndex: { _ in position }
            )
            XCTAssertEqual(result.correctIndex, position)
            XCTAssertEqual(result.options[position], "正解")
        }
    }
}
