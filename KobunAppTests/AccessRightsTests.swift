import XCTest
@testable import KobunApp

/// 出題範囲の権利判定と試用期間のテスト。
///
/// ここは収益に直結する一方、間違えても画面上は正常に見える
/// （全部出題されてしまう／逆に無料の項目まで出なくなる）ため、値型のまま検証する。
final class AccessRightsTests: XCTestCase {

    func testLockedRightsAllowOnlyFreeItems() {
        let rights = AccessRights.locked

        XCTAssertFalse(rights.hasFullAccess)
        XCTAssertTrue(rights.canStudy(isFree: true), "無料範囲は権利が無くても出題する")
        XCTAssertFalse(rights.canStudy(isFree: false))
    }

    func testTrialGrantsFullAccess() {
        let rights = AccessRights(isPurchased: false, isTrialActive: true)

        XCTAssertTrue(rights.hasFullAccess)
        XCTAssertTrue(rights.canStudy(isFree: false))
    }

    func testPurchaseGrantsFullAccessEvenAfterTrialEnds() {
        let rights = AccessRights(isPurchased: true, isTrialActive: false)

        XCTAssertTrue(rights.hasFullAccess)
        XCTAssertTrue(rights.canStudy(isFree: false))
    }

    /// 購入済みの表示が試用中の表示に負けると、買ったのに「お試し中」と出てしまう
    func testSummaryPrefersPurchasedOverTrial() {
        let both = AccessRights(isPurchased: true, isTrialActive: true)
        XCTAssertTrue(both.summary.contains("購入済み"))
        XCTAssertFalse(AccessRights.locked.summary.contains("購入済み"))
    }

    // MARK: - 試用期間

    /// テストが本物の UserDefaults を汚さないよう、専用のスイートを使う
    private func makeDefaults(name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    func testTrialStartsOnFirstLaunchAndLastsFourteenDays() {
        let trial = TrialManager(defaults: makeDefaults())
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        trial.startIfNeeded(now: start)

        XCTAssertEqual(TrialManager.trialDays, 14)
        XCTAssertTrue(trial.isActive(now: start))
        XCTAssertTrue(trial.isActive(now: start.addingTimeInterval(13 * 86_400)))
        XCTAssertFalse(trial.isActive(now: start.addingTimeInterval(15 * 86_400)))
    }

    @MainActor
    func testTrialStartIsNotResetOnLaterLaunches() {
        let defaults = makeDefaults()
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let first = TrialManager(defaults: defaults)
        first.startIfNeeded(now: start)

        let later = TrialManager(defaults: defaults)
        later.startIfNeeded(now: start.addingTimeInterval(10 * 86_400))

        XCTAssertEqual(later.startedAt, first.startedAt, "起動のたびに試用が延びてはいけない")
    }

    @MainActor
    func testTrialIgnoresClockRollback() {
        let defaults = makeDefaults()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)

        trial.startIfNeeded(now: start)
        // 期間の終了後まで進める（観測済みの最新日時として記録される）
        trial.startIfNeeded(now: start.addingTimeInterval(20 * 86_400))

        // 端末の時計を開始直後まで戻す
        XCTAssertFalse(trial.isActive(now: start.addingTimeInterval(86_400)),
                       "時計を戻して試用を延長できてはいけない")
    }

    @MainActor
    func testDaysRemainingIsNilAfterExpiry() {
        let trial = TrialManager(defaults: makeDefaults())
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        trial.startIfNeeded(now: start)

        XCTAssertEqual(trial.daysRemaining(now: start), 14)
        XCTAssertEqual(trial.daysRemaining(now: start.addingTimeInterval(13.5 * 86_400)), 1,
                       "残りが1日未満でも0日とは出さない（切り上げ）")
        XCTAssertNil(trial.daysRemaining(now: start.addingTimeInterval(20 * 86_400)))
    }
}
