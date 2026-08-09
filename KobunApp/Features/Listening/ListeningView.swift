import SwiftUI
import SwiftData

/// 聞き流し。画面を見ずに使う機能なので、操作はロック画面からも行える
/// （`AudioPlaybackManager` がリモートコマンドを登録している）。
struct ListeningView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ListeningViewModel()
    @State private var player = AudioPlaybackManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StatusFilterCard(
                        title: "再生する単語（\(viewModel.items.count)語）",
                        selection: Bindable(viewModel).statusFilter
                    )
                    nowPlayingCard
                    controls
                    speedCard
                    playSettingsCard
                    if !viewModel.items.isEmpty { playlist }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("聞き流し")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.configure(context: context) }
        // 対象が変わったら再生を止める。いま聞こえている語が一覧から消えた状態で
        // 再生が続くと、どこを流しているのか分からなくなるため。
        .onChange(of: viewModel.statusFilter) { _, _ in player.stop() }
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 8) {
            if let item = player.currentItem {
                Text(item.word)
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                if item.word != item.reading {
                    Text(item.reading)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Text(item.meaning)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("\(currentPosition) / \(viewModel.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else if viewModel.items.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("再生を開始すると単語が表示されます")
                    .foregroundStyle(.secondary)
                Text("全 \(viewModel.items.count) 語")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("画面を消したままでも再生は続きます")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    /// 0語の理由を言い分ける。同じ文言だと「絞り込みを外せば聞ける」ことに気づけない
    private var emptyMessage: String {
        if viewModel.statusFilter != nil && viewModel.unfilteredCount > 0 {
            return "この絞り込みに該当する単語がありません。\n「すべて」に戻すと再生できます。"
        }
        return "再生できる単語がありません。"
    }

    private var currentPosition: Int {
        min(player.currentIndex + 1, viewModel.items.count)
    }

    /// 停止・前・再生/一時停止・次を1列に並べる。
    /// 停止だけ離れた場所にあると、止めたいときに探すことになる。
    private var controls: some View {
        HStack(spacing: 24) {
            Button {
                player.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
            }
            .disabled(player.state == .stopped)
            .accessibilityLabel("停止")

            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .disabled(player.state == .stopped || player.currentIndex == 0)
            .accessibilityLabel("前の単語")

            Button {
                togglePlayPause()
            } label: {
                Image(systemName: playPauseSymbolName)
                    .font(.system(size: 44))
            }
            .disabled(viewModel.items.isEmpty)
            .accessibilityLabel(player.state == .playing ? "一時停止" : "再生")

            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .disabled(player.state == .stopped)
            .accessibilityLabel("次の単語")
        }
    }

    private var playPauseSymbolName: String {
        player.state == .playing ? "pause.circle.fill" : "play.circle.fill"
    }

    private func togglePlayPause() {
        switch player.state {
        case .stopped: viewModel.play()
        case .playing: player.pause()
        case .paused: player.resume()
        }
    }

    private var speedCard: some View {
        DashboardCard(title: "再生速度") {
            Picker("再生速度", selection: Bindable(viewModel).speed) {
                ForEach(ListeningViewModel.speedOptions, id: \.self) { speed in
                    Text(speed == 1.0 ? "標準" : String(format: "%.1f倍", speed))
                        .tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var playSettingsCard: some View {
        DashboardCard(title: "再生の設定") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("順番をシャッフルする", isOn: Bindable(viewModel).isShuffled)
                Toggle("例文と訳も読み上げる", isOn: Bindable(viewModel).readsExample)
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
