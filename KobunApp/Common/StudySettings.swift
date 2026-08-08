import Foundation

/// 画面（View）だけでなく ViewModel からも読む設定。
/// @AppStorage は View 専用なので、UserDefaults を直接扱うこの型に集約する。
enum StudySettings {
    private enum Key {
        static let pronouncesWords = "pronouncesWords"
        static let listeningSpeed = "listeningSpeed"
        static let listeningShuffle = "listeningShuffle"
        static let listeningReadsExample = "listeningReadsExample"
    }

    /// 出題された語を読み上げるか。
    /// 古語の音の響きは意味の記憶と結びつくので既定は入れておくが、電車の中などで切れるようにする。
    static var pronouncesWords: Bool {
        get { UserDefaults.standard.object(forKey: Key.pronouncesWords) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.pronouncesWords) }
    }

    /// 聞き流しの読み上げ速度（倍率）。0が入っている場合は既定に倒す
    static var listeningSpeed: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: Key.listeningSpeed)
            return stored > 0 ? stored : 1.0
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.listeningSpeed) }
    }

    /// 聞き流しの並びをシャッフルするか。既定は五十音順（辞書を引く感覚に近い）
    static var listeningShuffle: Bool {
        get { UserDefaults.standard.bool(forKey: Key.listeningShuffle) }
        set { UserDefaults.standard.set(newValue, forKey: Key.listeningShuffle) }
    }

    /// 聞き流しで例文と訳まで読み上げるか。
    /// 既定はオフ。1語あたりの時間が3倍近くになり、まず語と意味を回したい人には冗長なため。
    static var listeningReadsExample: Bool {
        get { UserDefaults.standard.bool(forKey: Key.listeningReadsExample) }
        set { UserDefaults.standard.set(newValue, forKey: Key.listeningReadsExample) }
    }
}
