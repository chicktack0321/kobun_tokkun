import SwiftUI
import SwiftData

/// ホーム右上の歯車から開く。タブを増やさずに済ませるため、
/// 学習に直接関わらない項目（音の設定・収録内容・アプリ情報）をここにまとめる。
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var audio = GameAudio.shared
    @State private var pronouncesWords = StudySettings.pronouncesWords
    @State private var counts = (words: 0, grammar: 0, quiz: 0)

    var body: some View {
        List {
            Section("音") {
                Toggle("効果音とBGM", isOn: Bindable(audio).isEnabled)
                Toggle("出題した語を読み上げる", isOn: $pronouncesWords)
                    .onChange(of: pronouncesWords) { _, newValue in
                        StudySettings.pronouncesWords = newValue
                        if !newValue { WordPronouncer.shared.stop() }
                    }
            }

            Section("収録内容") {
                LabeledContent("古文単語", value: "\(counts.words) 語")
                LabeledContent("文法項目", value: "\(counts.grammar) 項目")
                LabeledContent("文法問題", value: "\(counts.quiz) 問")
            }

            Section("このアプリについて") {
                Link(destination: AppConfig.privacyPolicyURL) {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
                Link(destination: AppConfig.supportURL) {
                    Label("サポート・お問い合わせ", systemImage: "questionmark.circle")
                }
                LabeledContent("バージョン", value: appVersion)
            }

            Section {
                Text("すべての機能を無料でご利用いただけます。App内課金・広告・サブスクリプションはありません。通信・アカウント登録なしで動作し、学習の記録は端末内にのみ保存されます。読み上げにはiOS標準の音声合成を使用しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let content = ContentRepository(context: context)
            counts = (content.wordCount(), content.allGrammar().count, content.grammarQuizCount())
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}
