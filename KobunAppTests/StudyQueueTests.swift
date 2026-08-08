import XCTest
@testable import KobunApp

/// 出題順のテスト。
///
/// ランダム出題に退化しても画面上は正常に見えるため、優先度の並びを機械的に検証する。
/// `StudyQueue` は単語と文法問題の両方に使われるので、テスト用の軽い型で検証する。
final class StudyQueueTests: XCTestCase {

    /// SwiftData の `@Model` を作らずに済ませるためのテスト用スタブ。
    /// `StudyQueue` は `StudyItem` にしか依存していないので、これで十分に検証できる。
    private struct StubItem: StudyItem, Equatable {
        let studyItemId: String
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func progress(
        id: String,
        attempts: Int,
        nextReviewOffsetDays: Int?
    ) -> ItemProgress {
        ItemProgress(
            itemId: id,
            correctCount: attempts,
            attemptCount: attempts,
            nextReviewAt: nextReviewOffsetDays.map { now.addingTimeInterval(Double($0) * 86_400) }
        )
    }

    func testDueItemsComeBeforeUnstudied() {
        let items = [StubItem(studyItemId: "due"), StubItem(studyItemId: "new"), StubItem(studyItemId: "later")]
        let progressById = [
            "due": progress(id: "due", attempts: 2, nextReviewOffsetDays: -1),
            "later": progress(id: "later", attempts: 2, nextReviewOffsetDays: 5)
        ]

        let ordered = StudyQueue.prioritize(items: items, progress: progressById, now: now)

        XCTAssertEqual(ordered.map(\.studyItemId), ["due", "new", "later"],
                       "期限切れ → 未学習 → 期限前 の順に並べる")
    }

    func testScheduledItemsAreSortedByNearestDueDate() {
        let items = [
            StubItem(studyItemId: "far"),
            StubItem(studyItemId: "near"),
            StubItem(studyItemId: "middle")
        ]
        let progressById = [
            "far": progress(id: "far", attempts: 1, nextReviewOffsetDays: 30),
            "near": progress(id: "near", attempts: 1, nextReviewOffsetDays: 1),
            "middle": progress(id: "middle", attempts: 1, nextReviewOffsetDays: 7)
        ]

        let ordered = StudyQueue.prioritize(items: items, progress: progressById, now: now)

        XCTAssertEqual(ordered.map(\.studyItemId), ["near", "middle", "far"],
                       "期限前の項目だけは期限が近い順を保つ")
    }

    func testProgressRowWithoutAttemptsCountsAsUnstudied() {
        // 「行はあるが一度も解いていない」状態。markAsMemorized 等を経ずに行だけできる経路がある
        let items = [StubItem(studyItemId: "a"), StubItem(studyItemId: "b")]
        let progressById = ["a": progress(id: "a", attempts: 0, nextReviewOffsetDays: 10)]

        let ordered = StudyQueue.prioritize(items: items, progress: progressById, now: now)

        XCTAssertEqual(Set(ordered.map(\.studyItemId)), ["a", "b"])
        XCTAssertEqual(ordered.count, 2, "解答回数0の行は未学習として扱い、期限前に回さない")
    }

    func testStudiedItemWithoutScheduleIsTreatedAsDue() {
        // 旧バージョンからの移行データを想定（解いた記録はあるが日程が無い）
        let items = [StubItem(studyItemId: "legacy"), StubItem(studyItemId: "new")]
        let progressById = ["legacy": progress(id: "legacy", attempts: 3, nextReviewOffsetDays: nil)]

        let ordered = StudyQueue.prioritize(items: items, progress: progressById, now: now)

        XCTAssertEqual(ordered.first?.studyItemId, "legacy")
    }

    func testDueItemsExcludesUnstudied() {
        let items = [StubItem(studyItemId: "due"), StubItem(studyItemId: "new")]
        let progressById = ["due": progress(id: "due", attempts: 1, nextReviewOffsetDays: -1)]

        let due = StudyQueue.dueItems(items: items, progress: progressById, now: now)

        XCTAssertEqual(due.map(\.studyItemId), ["due"],
                       "未学習は『復習』ではないので復習専用の出題には含めない")
    }

    func testDueCountMatchesDueItems() {
        let items = (0..<5).map { StubItem(studyItemId: "item\($0)") }
        let progressById = [
            "item0": progress(id: "item0", attempts: 1, nextReviewOffsetDays: -3),
            "item1": progress(id: "item1", attempts: 1, nextReviewOffsetDays: -1),
            "item2": progress(id: "item2", attempts: 1, nextReviewOffsetDays: 4)
        ]

        XCTAssertEqual(StudyQueue.dueCount(items: items, progress: progressById, now: now), 2)
        XCTAssertEqual(
            StudyQueue.dueCount(items: items, progress: progressById, now: now),
            StudyQueue.dueItems(items: items, progress: progressById, now: now).count,
            "件数表示と実際の出題数は必ず一致させる"
        )
    }

    func testEmptyInput() {
        let empty: [StubItem] = []
        XCTAssertTrue(StudyQueue.prioritize(items: empty, progress: [:], now: now).isEmpty)
        XCTAssertEqual(StudyQueue.dueCount(items: empty, progress: [:], now: now), 0)
    }
}
