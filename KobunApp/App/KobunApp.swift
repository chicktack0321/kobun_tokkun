import SwiftUI
import SwiftData

@main
struct KobunApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                // 試用の起点の記録・購入状態の読み直し・払い戻しの購読をここで始める。
                // 起動直後に確定させないと、権利が無い状態で一瞬だけ全項目が出題対象になる。
                .task { Entitlements.shared.start() }
        }
        .modelContainer(AppContainer.shared)
    }
}

/// ソーシャル機能を一切持たないため、タブは「学習」に直結する最小構成にする。
/// 文法は独立したタブにせず単語帳の中のセグメントに入れている。
/// タブを5つに増やすより、「覚える対象の一覧」という同じ役割の画面をまとめるほうが迷いが少ない。
struct RootTabView: View {
    @State private var router = TabRouter()

    var body: some View {
        TabView(selection: Bindable(router).selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(AppTab.home)

            LibraryView()
                .tabItem { Label("単語帳", systemImage: "text.book.closed") }
                .tag(AppTab.wordList)

            QuizView()
                .tabItem { Label("4択クイズ", systemImage: "checkmark.circle") }
                .tag(AppTab.quiz)

            ListeningView()
                .tabItem { Label("聞き流し", systemImage: "headphones") }
                .tag(AppTab.listening)
        }
        .environment(router)
    }
}
