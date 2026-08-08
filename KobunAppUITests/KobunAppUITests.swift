import XCTest

/// 実機やMacが手元になくても各画面の見た目を確認できるよう、主要画面を一通り遷移しながら
/// スクリーンショットを撮る。CIでは `xcparse` を使って `.xcresult` からPNGとして取り出し、
/// ワークフローのアーティファクトとしてアップロードする（`.github/workflows/ios-build.yml` を参照）。
final class KobunAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // 1画面の遷移に失敗しても、それまでに撮れたスクリーンショットは失わずに済むよう続行する
        continueAfterFailure = true
    }

    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launch()

        capture(app, "01_Home")

        captureHistory(app)
        captureLibrary(app)
        captureQuiz(app)
        captureListening(app)
        captureSettings(app)
    }

    // MARK: - 画面ごと

    /// ホーム → 学習の記録（push）→ 戻る
    private func captureHistory(_ app: XCUIApplication) {
        // 「学習の記録」カード全体がリンクなので、見出しのテキストから辿る
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS '連続学習'")).firstMatch
        guard card.waitForExistence(timeout: 5) else { return }
        guard tapIfPossible(card, in: app) else { return }

        capture(app, "02_StudyHistory")
        goBack(app)
    }

    /// 単語帳タブ。単語一覧 → 単語詳細 → 文法一覧 → 文法詳細
    private func captureLibrary(_ app: XCUIApplication) {
        guard selectTab(app, "単語帳") else { return }
        capture(app, "03_WordList")

        let firstWord = app.cells.element(boundBy: 0)
        if firstWord.waitForExistence(timeout: 5), tapIfPossible(firstWord, in: app) {
            capture(app, "04_WordDetail")
            goBack(app)
        }

        // セグメントで文法へ切り替える
        let grammarSegment = app.segmentedControls.buttons["文法"]
        if grammarSegment.waitForExistence(timeout: 5), tapIfPossible(grammarSegment, in: app) {
            capture(app, "05_GrammarList")

            let firstGrammar = app.cells.element(boundBy: 0)
            if firstGrammar.waitForExistence(timeout: 5), tapIfPossible(firstGrammar, in: app) {
                capture(app, "06_GrammarDetail")
                goBack(app)
            }
        }
    }

    /// クイズタブ。スタート画面 → 単語クイズを1問解いて解説まで
    private func captureQuiz(_ app: XCUIApplication) {
        guard selectTab(app, "4択クイズ") else { return }
        capture(app, "07_QuizStart")

        // 「はじめる」は単語・文法の2つある。先頭（単語クイズ）を押す
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS 'はじめる'")).firstMatch
        guard start.waitForExistence(timeout: 5), tapIfPossible(start, in: app) else { return }
        capture(app, "08_QuizQuestion")

        // 選択肢を1つ選び、正誤と解説が出た状態を撮る。
        // どれを選んでも解説は出るので、正解かどうかは問わない。
        let choice = app.buttons.element(boundBy: 3)
        if choice.waitForExistence(timeout: 5), tapIfPossible(choice, in: app) {
            capture(app, "09_QuizAnswered")
        }

        // 進行中のまま他タブへ移ると次回の撮影に影響するので、明示的に終了させる
        let quit = app.buttons["やめる"]
        if quit.waitForExistence(timeout: 3) { _ = tapIfPossible(quit, in: app) }
    }

    private func captureListening(_ app: XCUIApplication) {
        guard selectTab(app, "聞き流し") else { return }
        capture(app, "10_Listening")
    }

    /// ホーム右上の歯車 → 設定 → 購入画面
    private func captureSettings(_ app: XCUIApplication) {
        guard selectTab(app, "ホーム") else { return }

        let gear = app.buttons["設定"]
        guard gear.waitForExistence(timeout: 5), tapIfPossible(gear, in: app) else { return }
        capture(app, "11_Settings")

        let paywallLink = app.buttons.matching(NSPredicate(format: "label CONTAINS '出題範囲'")).firstMatch
        if paywallLink.waitForExistence(timeout: 5), tapIfPossible(paywallLink, in: app) {
            capture(app, "12_Paywall")
            goBack(app)
        }
        goBack(app)
    }

    // MARK: - 補助

    private func selectTab(_ app: XCUIApplication, _ label: String) -> Bool {
        let tab = app.tabBars.buttons[label]
        guard tab.waitForExistence(timeout: 5) else { return false }
        tab.tap()
        settle()
        return true
    }

    /// 画面下方にあって初期表示では隠れている要素があるため、必要なら1度だけスクロールして押す
    private func tapIfPossible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if !element.isHittable {
            app.swipeUp()
            settle()
        }
        guard element.isHittable else { return false }
        element.tap()
        settle()
        return true
    }

    private func goBack(_ app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5), backButton.isHittable {
            backButton.tap()
            settle()
        }
    }

    /// 遷移アニメーションの途中で撮ると画面が混ざったスクリーンショットになる
    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
