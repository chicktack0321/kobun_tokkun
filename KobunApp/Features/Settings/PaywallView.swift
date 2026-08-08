import SwiftUI
import StoreKit

/// 買い切りの解放画面。
///
/// 広告とサブスクリプションは実装しない方針なので、案内するのはこの1商品だけ。
/// 「試用が終わると使えなくなる」という誤解を招かないよう、
/// 制限されるのが出題範囲だけであることを最初に書く。
struct PaywallView: View {
    @State private var entitlements = Entitlements.shared
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                benefitsCard
                if !entitlements.rights.isPurchased { purchaseCard }
                restoreCard
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("すべてを解放")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: entitlements.rights.isPurchased ? "checkmark.seal.fill" : "lock.open")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            Text(entitlements.accessSummary)
                .font(.headline)
            if let days = entitlements.trialDaysRemaining, !entitlements.rights.isPurchased {
                Text("お試し期間はあと \(days) 日です")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var benefitsCard: some View {
        DashboardCard(title: "解放されるもの", infoMessage: MetricExplanations.freeRange) {
            VStack(alignment: .leading, spacing: 10) {
                Label("すべての古文単語がクイズ・聞き流しの対象になります", systemImage: "character.book.closed")
                Label("すべての文法問題が出題対象になります", systemImage: "text.badge.checkmark")
                Divider()
                Text("単語帳と文法解説の閲覧・検索・読み上げは、購入の有無にかかわらず常にすべて使えます。お試し期間が終わってもクイズと聞き流しは使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var purchaseCard: some View {
        DashboardCard(title: "買い切り") {
            VStack(alignment: .leading, spacing: 12) {
                if let product = entitlements.product {
                    Text("\(product.displayName) \(product.displayPrice)")
                        .font(.title3.bold())
                    Text(product.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    // 電波の無い場所では読めなくて当然。買えないことだけ伝えて学習は続けさせる
                    Text("商品情報を読み込めませんでした。通信環境をご確認ください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await purchase() }
                } label: {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("購入する").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(entitlements.product == nil || isWorking)

                Text("買い切りです。月額・年額の課金や広告はありません。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 機種変更・再インストール後の復元。App Review で導線の有無を確認される。
    private var restoreCard: some View {
        DashboardCard(title: "購入の復元") {
            VStack(alignment: .leading, spacing: 10) {
                Text("機種変更や再インストールのあとは、こちらから購入を復元できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await restore() }
                } label: {
                    Text("購入を復元する").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
            }
        }
    }

    private func purchase() async {
        isWorking = true
        defer { isWorking = false }
        switch await entitlements.purchase() {
        case .purchased:
            message = "購入が完了しました。すべての単語・文法が出題対象になります。"
        case .cancelled:
            message = nil
        case .pending:
            message = "購入の承認を待っています。承認されると自動で反映されます。"
        case .failed(let reason):
            message = reason
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        message = await entitlements.restorePurchases()
            ? "購入を復元しました。"
            : "復元できる購入が見つかりませんでした。"
    }
}
