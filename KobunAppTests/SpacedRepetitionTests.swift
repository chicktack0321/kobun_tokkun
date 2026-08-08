import XCTest
@testable import KobunApp

/// 間隔反復のテスト。
///
/// このロジックが壊れても画面上は正常に見え、学習効果だけが静かに落ちる
/// （復習が来ない・毎回同じ項目ばかり出る）。参考元アプリから移植した規則をそのまま検証する。
final class SpacedRepetitionTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testNewItemIsNotStudied() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        XCTAssertEqual(progress.status(), .notStudied)
        XCTAssertTrue(progress.isDue(), "未出題の項目はいつでも出題できる")
    }

    func testCorrectAnswerAdvancesBox() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let now = date(2026, 8, 8)

        progress.record(isCorrect: true, reviewedAt: now, calendar: calendar)

        XCTAssertEqual(progress.reviewBox, 1)
        XCTAssertEqual(progress.correctCount, 1)
        XCTAssertEqual(progress.attemptCount, 1)
        // box1 の間隔は1日
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: date(2026, 8, 9)))
    }

    func testWrongAnswerResetsBoxToZero() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let now = date(2026, 8, 8)

        for _ in 0..<3 { progress.record(isCorrect: true, reviewedAt: now, calendar: calendar) }
        XCTAssertEqual(progress.reviewBox, 3)

        progress.record(isCorrect: false, reviewedAt: now, calendar: calendar)

        XCTAssertEqual(progress.reviewBox, 0, "間違えたら最短間隔に戻す")
        // box0 の間隔は0日 = その日のうちにまた出す
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: now))
        XCTAssertTrue(progress.isDue(at: now))
    }

    func testMemorizedRequiresSevenDayInterval() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        var day = date(2026, 8, 8)

        // 3回正解して box3（間隔7日）に到達したときに初めて「覚えた」になる
        for expectedBox in 1...3 {
            progress.record(isCorrect: true, reviewedAt: day, calendar: calendar)
            XCTAssertEqual(progress.reviewBox, expectedBox)
            day = calendar.date(byAdding: .day, value: ItemProgress.intervalDays(forBox: expectedBox), to: day)!
        }

        XCTAssertEqual(ItemProgress.masteredBox, 3)
        // 期限前（次の復習日より手前）で評価すれば「覚えた」
        let beforeDue = calendar.date(byAdding: .day, value: -1, to: progress.nextReviewAt!)!
        XCTAssertEqual(progress.status(at: beforeDue), .memorized)
    }

    func testDueItemIsNeedsReviewEvenIfBoxIsHigh() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let start = date(2026, 8, 8)
        for _ in 0..<4 { progress.record(isCorrect: true, reviewedAt: start, calendar: calendar) }

        let afterDue = calendar.date(byAdding: .day, value: 60, to: start)!
        XCTAssertEqual(progress.status(at: afterDue), .needsReview,
                       "箱が進んでいても期限が過ぎたら要復習にする")
    }

    func testReviewDateIsRoundedToStartOfDay() {
        let morning = ItemProgress(itemId: "A")
        let night = ItemProgress(itemId: "B")

        morning.record(isCorrect: true, reviewedAt: date(2026, 8, 8, hour: 7), calendar: calendar)
        night.record(isCorrect: true, reviewedAt: date(2026, 8, 8, hour: 23), calendar: calendar)

        XCTAssertEqual(morning.nextReviewAt, night.nextReviewAt,
                       "朝に解いても夜に解いても復習期限は同じ日にする")
    }

    func testMarkAsMemorizedFromUnstudied() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let now = date(2026, 8, 8)

        progress.markAsMemorized(at: now, calendar: calendar)

        XCTAssertGreaterThanOrEqual(progress.reviewBox, ItemProgress.masteredBox)
        XCTAssertEqual(progress.attemptCount, 1, "未出題のままだと status が notStudied に戻ってしまう")
        XCTAssertEqual(progress.status(at: now), .memorized)
    }

    func testMarkForReviewMakesItemDueImmediately() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let now = date(2026, 8, 8)
        for _ in 0..<5 { progress.record(isCorrect: true, reviewedAt: now, calendar: calendar) }

        progress.markForReview(at: now, calendar: calendar)

        XCTAssertEqual(progress.reviewBox, 0)
        XCTAssertTrue(progress.isDue(at: now))
        XCTAssertEqual(progress.status(at: now), .needsReview)
    }

    func testBoxDoesNotExceedMaximum() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST")
        let now = date(2026, 8, 8)
        for _ in 0..<20 { progress.record(isCorrect: true, reviewedAt: now, calendar: calendar) }

        XCTAssertEqual(progress.reviewBox, ItemProgress.maxReviewBox)
        XCTAssertEqual(ItemProgress.intervalDays(forBox: 99), 30, "範囲外の箱でも最大間隔に丸める")
    }

    func testAccuracy() {
        let progress = ItemProgress(itemId: "KOBUN_W_TEST", correctCount: 3, attemptCount: 4)
        XCTAssertEqual(progress.accuracy, 0.75, accuracy: 0.0001)
        XCTAssertEqual(ItemProgress(itemId: "X").accuracy, 0, "0除算にしない")
    }
}
