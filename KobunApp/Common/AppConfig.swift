import Foundation

/// アプリ全体で使う定数と、外部に公開しているURLの置き場所。
///
/// 参考元（英単語アプリ）は級ごとの別アプリ展開を前提に級依存の値を集約していたが、
/// 本アプリは単体アプリなので「散らばると変更漏れが起きる値」だけをここに置く。
enum AppConfig {
    /// アプリ名（ホーム画面のアイコン下は Info.plist の CFBundleDisplayName が担う）
    static let appDisplayName = "古文特訓"

    /// 同梱する学習データ（拡張子を除いたファイル名）
    static let seedResourceName = "kobun_seed"

    /// App内課金のプロダクトID
    static let unlockProductID = "com.eitango.kobun.unlock.full"

    /// ロック画面・コントロールセンターに出すアルバム名（聞き流し）
    static let nowPlayingAlbumTitle = "古文単語 聞き流し"

    /// ログのサブシステム名。bundle ID と揃える
    static let loggingSubsystem = "com.eitango.kobun"

    // MARK: - 公開ページ

    /// App Store Connect にも同じURLを登録する（プライバシーポリシーは全アプリで必須）
    static let privacyPolicyURL = URL(string: "https://sites.google.com/view/kobun-tokkun/privacy-policy")!
    static let supportURL = URL(string: "https://sites.google.com/view/kobun-tokkun/support")!
}
