import Foundation

/// 画面（View）だけでなく ViewModel からも読む設定。
/// @AppStorage は View 専用なので、UserDefaults を直接扱うこの型に集約する。
enum StudySettings {
    private enum Key {
        static let pronouncesWords = "pronouncesWords"
        static let listeningSpeed = "listeningSpeed"
        static let listeningShuffle = "listeningShuffle"
        static let listeningReadsExample = "listeningReadsExample"
        static let quizStatusFilter = "quizStatusFilter"
        static let listeningStatusFilter = "listeningStatusFilter"
    }

    /// クイズの出題を習熟段階で絞る（nil はすべて）。
    /// クイズと聞き流しで別々に持つ。「要復習だけ聞き流しつつ、クイズは全体を回す」のように
    /// 使い分けたい場面があり、片方を変えたらもう片方も変わるのは意図と違う。
    static var quizStatusFilter: LearningStatus? {
        get { loadStatus(Key.quizStatusFilter) }
        set { saveStatus(newValue, to: Key.quizStatusFilter) }
    }

    /// 聞き流しの再生対象を習熟段階で絞る（nil はすべて）
    static var listeningStatusFilter: LearningStatus? {
        get { loadStatus(Key.listeningStatusFilter) }
        set { saveStatus(newValue, to: Key.listeningStatusFilter) }
    }

    private static func loadStatus(_ key: String) -> LearningStatus? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return LearningStatus(rawValue: raw)
    }

    private static func saveStatus(_ status: LearningStatus?, to key: String) {
        if let status {
            UserDefaults.standard.set(status.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
