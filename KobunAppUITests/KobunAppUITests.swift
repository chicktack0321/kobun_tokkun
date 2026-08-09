import XCTest

/// 実機やMacが手元になくても各画面の見た目を確認できるよう、主要画面を一通り遷移しながら
/// スクリーンショットを撮る。CIでは `xcparse` を使って `.xcresult` からPNGとして取り出し、
/// ワークフローのアーティファクトとしてアップロードする（`.github/workflows/ios-build.yml` を参照）。
///
/// - Important: 遷移に失敗したら**必ずテストを失敗させる**こと。
///   初版は各ステップを `guard ... else { return }` で飛ばしていたため、
///   選択肢のつもりでタブバーを押していた（`element(boundBy:)` の添字ずれ）にもかかわらず
///   テストは成功し、単語詳細・文法詳細を一度も撮らないまま「12枚撮れた」ことになっていた。
///   撮れないこと自体が不具合なので、素通りさせない。
final class KobunAppUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        // 1画面の遷移に失敗しても、それまでに撮れたスクリーンショットは失わずに済むよう続行する。
        // 失敗は記録されるので、素通りとは区別される。
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    func testCaptureAllScreens() throws {
        capture("01_Home")

        captureHistory()
        captureWordList()
        captureGrammarList()
        captureQuiz()
        captureListening()
        captureSettings()
    }

    // MARK: - 画面ごと

    /// ホーム → 学習の記録（push）→ 戻る
    private func captureHistory() {
        tap(id: UITestID.historyCardLink, describing: "ホームの学習の記録カード")
        assertOnScreen(title: "学習の記録")
        capture("02_StudyHistory")
        goBack()
    }

    /// 単語帳タブ。単語一覧 → 単語詳細
    private func captureWordList() {
        selectTab("単語帳")
        assertOnScreen(title: "単語帳")
        capture("03_WordList")

        tap(id: UITestID.libraryRow, describing: "単語一覧の先頭行")
        // 詳細は見出し語がタイトルになるので固定文言では確かめられない。
        // 一覧に戻っていないこと（＝遷移したこと）を「意味」カードの有無で確かめる。
        XCTAssertTrue(
            app.staticTexts["意味"].waitForExistence(timeout: 5),
            "単語詳細へ遷移できていない（一覧のまま撮影される）"
        )
        capture("04_WordDetail")
        goBack()
    }

    /// セグメントで文法へ切り替え、文法一覧 → 文法詳細
    private func captureGrammarList() {
        let grammarSegment = app.segmentedControls.buttons["文法"]
        XCTAssertTrue(grammarSegment.waitForExistence(timeout: 5), "単語/文法のセグメントが見つからない")
        grammarSegment.tap()
        settle()
        XCTAssertTrue(app.staticTexts["助動詞"].waitForExistence(timeout: 5), "文法一覧に切り替わっていない")
        capture("05_GrammarList")

        tap(id: UITestID.libraryRow, describing: "文法一覧の先頭行")
        XCTAssertTrue(
            app.staticTexts["解説"].waitForExistence(timeout: 5),
            "文法詳細へ遷移できていない（一覧のまま撮影される）"
        )
        capture("06_GrammarDetail")
        goBack()
    }

    /// クイズタブ。スタート画面 → 単語クイズを1問解いて解説まで
    private func captureQuiz() {
        selectTab("4択クイズ")
        assertOnScreen(title: "4択クイズ")
        capture("07_QuizStart")

        // 「はじめる」は単語・文法の2つある。先頭（単語クイズ）を押す
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS 'はじめる'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5), "クイズの開始ボタンが見つからない")
        start.tap()
        settle()
        XCTAssertTrue(app.buttons["やめる"].waitForExistence(timeout: 5), "クイズが開始されていない")
        capture("08_QuizQuestion")

        // 選択肢は識別子で狙う。添字で拾うとツールバーやタブバーのボタンを押してしまう。
        // どれを選んでも解説は出るので、正解かどうかは問わない。
        tap(id: UITestID.quizChoice, describing: "クイズの選択肢")
        XCTAssertTrue(
            app.buttons["次の問題へ"].waitForExistence(timeout: 5),
            "解答が記録されていない（解説と「次の問題へ」が出ていない）"
        )
        capture("09_QuizAnswered")

        // 進行中のまま他タブへ移ると次の撮影に影響するので、明示的に終了させる
        app.buttons["やめる"].tap()
        settle()
    }

    private func captureListening() {
        selectTab("聞き流し")
        assertOnScreen(title: "聞き流し")
        capture("10_Listening")
    }

    /// ホーム右上の歯車 → 設定
    private func captureSettings() {
        selectTab("ホーム")

        let gear = app.buttons["設定"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "設定ボタンが見つからない")
        gear.tap()
        settle()
        assertOnScreen(title: "設定")
        capture("11_Settings")
        goBack()
    }

    // MARK: - 補助

    /// 識別子で要素を探して押す。見つからない・押せない場合はテストを失敗させる。
    private func tap(id: String, describing description: String) {
        let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("\(description)（identifier: \(id)）が見つからない")
            return
        }
        if !element.isHittable {
            app.swipeUp()
            settle()
        }
        guard element.isHittable else {
            XCTFail("\(description)（identifier: \(id)）が画面に出ているが押せない")
            return
        }
        element.tap()
        settle()
    }

    private func selectTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "タブ「\(label)」が見つからない")
        tab.tap()
        settle()
    }

    /// ナビゲーションバーのタイトルで、狙った画面に居ることを確かめる。
    /// これが無いと、遷移に失敗しても前の画面を撮って成功したことになる。
    private func assertOnScreen(title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 5),
            "画面「\(title)」に居ない（別の画面を撮影しようとしている）",
            file: file, line: line
        )
    }

    private func goBack() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        guard backButton.waitForExistence(timeout: 5), backButton.isHittable else {
            XCTFail("戻るボタンが押せない")
            return
        }
        backButton.tap()
        settle()
    }

    /// 遷移アニメーションの途中で撮ると画面が混ざったスクリーンショットになる
    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
