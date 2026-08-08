import XCTest
@testable import KobunApp

/// 学習履歴の集計テスト。
///
/// 日付の扱いを間違えると「グラフが1日ずれる」「連続日数が途切れる」という、
/// 目で見て気づきにくい不具合になる。
final class StudyHistoryTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offsetFromToday: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offsetFromToday, to: calendar.startOfDay(for: today))!
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 15))!
    }

    func testSeriesFillsMissingDaysWithZero() {
        let logs = [
            StudyLog(date: day(-6, from: today), studiedItemCount: 10, correctCount: 8, attemptCount: 10),
            StudyLog(date: day(0, from: today), studiedItemCount: 5, correctCount: 5, attemptCount: 5)
        ]

        let series = StudyHistory.series(logs: logs, days: 7, endingOn: today, calendar: calendar)

        XCTAssertEqual(series.count, 7, "学習していない日を飛ばすと横軸が詰まって推移が読めない")
        XCTAssertEqual(series.first?.attemptCount, 10)
        XCTAssertEqual(series[1].attemptCount, 0)
        XCTAssertEqual(series.last?.attemptCount, 5)
    }

    func testSeriesIsOrderedOldestFirst() {
        let series = StudyHistory.series(logs: [], days: 5, endingOn: today, calendar: calendar)
        XCTAssertEqual(series.map(\.date), (0..<5).reversed().map { day(-$0, from: today) })
    }

    /// 期間内に学習日が無いと折れ線が0から始まり、覚えた語が消えたように見えてしまう
    func testMasteredCountIsCarriedForwardFromBeforeTheRange() {
        let logs = [
            StudyLog(date: day(-30, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1,
                     masteredWordCount: 42, masteredGrammarCount: 7)
        ]

        let series = StudyHistory.series(logs: logs, days: 7, endingOn: today, calendar: calendar)

        XCTAssertEqual(series.first?.masteredWordCount, 42)
        XCTAssertEqual(series.last?.masteredWordCount, 42)
        XCTAssertEqual(series.last?.masteredGrammarCount, 7)
    }

    func testStreakCountsConsecutiveDays() {
        let logs = (0..<3).map {
            StudyLog(date: day(-$0, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1)
        }
        XCTAssertEqual(StudyHistory.currentStreak(logs: logs, today: today, calendar: calendar), 3)
    }

    /// 朝アプリを開いた瞬間に0日と表示されると、続ける動機付けにならない
    func testStreakSurvivesWhenTodayHasNoRecordYet() {
        let logs = (1...3).map {
            StudyLog(date: day(-$0, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1)
        }
        XCTAssertEqual(StudyHistory.currentStreak(logs: logs, today: today, calendar: calendar), 3)
    }

    func testStreakBreaksOnAGap() {
        let logs = [
            StudyLog(date: day(0, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1),
            StudyLog(date: day(-1, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1),
            // -2 が抜けている
            StudyLog(date: day(-3, from: today), studiedItemCount: 1, correctCount: 1, attemptCount: 1)
        ]
        XCTAssertEqual(StudyHistory.currentStreak(logs: logs, today: today, calendar: calendar), 2)
    }

    func testStreakIgnoresDaysWithoutStudy() {
        let logs = [StudyLog(date: day(0, from: today), studiedItemCount: 0, correctCount: 0, attemptCount: 0)]
        XCTAssertEqual(StudyHistory.currentStreak(logs: logs, today: today, calendar: calendar), 0,
                       "行はあるが0件の日は学習日として数えない")
    }

    /// 日ごとの正答率を単純平均すると、1問だけ解いた日が重く効いてしまう
    func testOverallAccuracyIsWeightedByAttempts() {
        let series = [
            DailyStudy(date: day(-1, from: today), studiedItemCount: 1, correctCount: 0, attemptCount: 1),
            DailyStudy(date: day(0, from: today), studiedItemCount: 99, correctCount: 99, attemptCount: 99)
        ]

        let accuracy = StudyHistory.overallAccuracy(in: series)

        XCTAssertEqual(accuracy, 99.0 / 100.0, accuracy: 0.0001)
        XCTAssertNotEqual(accuracy, 0.5, accuracy: 0.0001, "日ごとの単純平均になっていないこと")
    }

    func testWeeklyAggregatesSumsAttemptsAndKeepsLastMastery() {
        let series = (0..<14).reversed().map { offset in
            DailyStudy(
                date: day(-offset, from: today),
                studiedItemCount: 1, correctCount: 1, attemptCount: 1,
                masteredWordCount: 14 - offset
            )
        }

        let weekly = StudyHistory.weekly(from: series, calendar: calendar)

        XCTAssertLessThan(weekly.count, series.count)
        XCTAssertEqual(weekly.reduce(0) { $0 + $1.attemptCount }, 14, "解答数は週内で合計する")
        XCTAssertEqual(weekly.last?.masteredWordCount, 14, "習熟度は残高なので週の最終値を採る")
    }

    func testEmptyInputs() {
        XCTAssertTrue(StudyHistory.series(logs: [], days: 0, endingOn: today, calendar: calendar).isEmpty)
        XCTAssertTrue(StudyHistory.weekly(from: [], calendar: calendar).isEmpty)
        XCTAssertEqual(StudyHistory.currentStreak(logs: [], today: today, calendar: calendar), 0)
        XCTAssertEqual(StudyHistory.overallAccuracy(in: []), 0)
    }
}
