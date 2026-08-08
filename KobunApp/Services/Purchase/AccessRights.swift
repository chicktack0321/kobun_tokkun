import Foundation

/// 出題対象にできる範囲を決める権利。
///
/// StoreKit にも UserDefaults にも触れない値型にしてある。
/// 「試用中はすべて、期間後は無料範囲だけ」という線引きは収益に直結し、
/// 間違えても画面上は正常に見えてしまうため、ここだけを取り出してテストできるようにする。
///
/// 参考元は語彙階層（Tier）で線を引いていたが、本アプリは階層を持たないため
/// 項目ごとの `isFree` フラグで判定する。
struct AccessRights: Equatable {
    /// 買い切りのアンロックを購入済みか
    var isPurchased: Bool
    /// 初回起動から14日間の試用期間中か
    var isTrialActive: Bool

    static let locked = AccessRights(isPurchased: false, isTrialActive: false)
    static let full = AccessRights(isPurchased: true, isTrialActive: false)

    var hasFullAccess: Bool { isPurchased || isTrialActive }

    /// この項目を出題（クイズ・聞き流し）の対象にできるか。
    ///
    /// 権利が無くても機能そのものは止めない。止まるのは有料項目が出題対象から
    /// 外れることだけで、単語帳・文法解説の閲覧・検索・読み上げは常に全項目できる。
    /// 一定期間後に動かなくなる体験版は App Review の拒否対象であり、
    /// 教育カテゴリでは「使えなくなった」という★1レビューを最も招くため。
    func canStudy(isFree: Bool) -> Bool {
        hasFullAccess || isFree
    }

    /// 画面に出す現在の状態
    var summary: String {
        if isPurchased { return "すべての単語・文法（購入済み）" }
        if isTrialActive { return "すべての単語・文法（お試し期間中）" }
        return "無料範囲の単語・文法"
    }
}
