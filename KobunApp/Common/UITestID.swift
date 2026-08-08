import Foundation

/// UIテストから要素を名指しするための識別子。
///
/// XCUITest 側で `element(boundBy:)` の添字や表示文言を頼りに要素を拾うと、
/// ツールバー・タブバーのボタンが同じ並びに混ざったり、データを差し替えた
/// 途端に見つからなくなったりする。しかも見つからなかったことは
/// 「その画面を撮らずに素通りする」形で現れ、テストは成功したまま通る。
///
/// 撮影対象の入口にだけ識別子を振り、テスト側はこの定数を使って辿る。
enum UITestID {
    /// 4択クイズの選択肢（4つとも同じ識別子。テスト側は firstMatch で拾う）
    static let quizChoice = "quizChoice"
    /// 単語帳・文法一覧の各行（詳細画面への入口）
    static let libraryRow = "libraryRow"
    /// ホームの「学習の記録」カード（学習履歴への入口）
    static let historyCardLink = "historyCardLink"
    /// 設定画面の「出題範囲」（購入画面への入口）
    static let paywallLink = "paywallLink"
}
