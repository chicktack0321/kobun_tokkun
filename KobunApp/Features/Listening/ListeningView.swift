import SwiftUI
import SwiftData

/// 聞き流し。画面を見ずに使う機能なので、操作はロック画面からも行える
/// （`AudioPlaybackManager` がリモートコマンドを登録している）。
struct ListeningView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ListeningViewModel()
    @State private var player = AudioPlaybackManager.shared
    @State private var entitlements = Entitlements.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nowPlayingCard
                    controls
                    settingsCard
                    if viewModel.isLimited { LockedRangeNotice() }
                    playlist
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("聞き流し")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.configure(context: context) }
        .onChange(of: entitlements.rights) { _, _ in viewModel.rebuild() }
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 8) {
            if let item = player.currentItem {
                Text(item.word)
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                if item.word != item.reading {
                    Text(item.reading)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Text(item.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("\(player.currentIndex + 1) / \(viewModel.items.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "headphones")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("\(viewModel.items.count) 語を続けて読み上げます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("画面を消したままでも再生は続きます")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .disabled(player.state == .stopped)

            Button {
                switch player.state {
                case .playing: player.pause()
                case .paused: player.resume()
                case .stopped: viewModel.play()
                }
            } label: {
                Image(systemName: player.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 58))
            }
            .disabled(viewModel.items.isEmpty)

            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
            .disabled(player.state == .stopped)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .trailing) {
            if player.state != .stopped {
                Button("停止") { player.stop() }
                    .font(.footnote)
            }
        }
    }

    private var settingsCard: some View {
        DashboardCard(title: "再生の設定") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("順番をシャッフルする", isOn: Bindable(viewModel).isShuffled)
                Toggle("例文と訳も読み上げる", isOn: Bindable(viewModel).readsExample)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("速さ")
                        Spacer()
                        Text(String(format: "%.1f倍", viewModel.speed))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    Slider(value: Bindable(viewModel).speed, in: 0.5...1.5, step: 0.1)
                }

                Text("速さの変更は次に読み上げる文から反映されます。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
        }
    }

    /// 一覧から任意の語に飛べるようにする。
    /// 順に聞くだけだと「あの語をもう一度」に戻れない。
    private var playlist: some View {
        DashboardCard(title: "再生リスト") {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        viewModel.play(from: index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.word)
                                    .font(.subheadline.weight(.medium))
                                Text(item.meaning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if player.currentItem?.id == item.id {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    if item.id != viewModel.items.last?.id { Divider() }
                }
            }
        }
    }
}
