import SwiftUI
import SwiftData

struct WordDetailView: View {
    let word: WordMaster
    /// 一覧から開いたときは共有し、クイズ結果から開いたときはこの画面で作る。
    /// 一覧を持たない経路でも「覚えた／やり直す」を使えるようにするため、既定値を持たせて省略可能にする。
    var viewModel: LibraryViewModel? = nil

    @Environment(\.modelContext) private var context
    @State private var ownViewModel = LibraryViewModel()

    private var model: LibraryViewModel { viewModel ?? ownViewModel }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headword
                meaningCard
                if !word.example.isEmpty { exampleCard }
                masteryCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil { ownViewModel.configure(context: context) }
        }
    }

    private var headword: some View {
        VStack(spacing: 8) {
            Text(word.word)
                .font(.system(size: 40, weight: .bold))
            if word.needsReadingAnnotation {
                Text(word.reading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text(word.partOfSpeech.displayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                Button {
                    // 読み上げるのは読み。見出し語をそのまま渡すと綴り字どおりに誤読される
                    WordPronouncer.shared.speak(reading: word.reading)
                } label: {
                    Label("読み上げ", systemImage: "speaker.wave.2")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var meaningCard: some View {
        DashboardCard(title: "意味") {
            Text(word.meaning)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var exampleCard: some View {
        DashboardCard(title: "例文") {
            VStack(alignment: .leading, spacing: 8) {
                Text(word.example)
                    .font(.body)
                Text(word.exampleTranslation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !word.source.isEmpty {
                    Text("出典: \(word.source)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var masteryCard: some View {
        // 段階は必ず `wordStatus` から読む。`progress(for:)` は監視対象のプロパティに触れないため、
        // これだけを読んでいると、クイズ結果から開いた直後（configure が走る前）の
        // 「未学習」表示が、読み込み完了後も更新されないまま残る。
        let status = model.wordStatus[word.wordId] ?? .notStudied
        let progress = model.progress(for: word.wordId)

        return DashboardCard(title: "習熟度", infoMessage: MetricExplanations.masteryStages) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: status.symbolName)
                        .foregroundStyle(status.tint)
                    Text(status.displayName)
                        .font(.body.weight(.medium))
                    Spacer()
                    if let progress, progress.attemptCount > 0 {
                        Text("\(progress.correctCount)/\(progress.attemptCount) 正解")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let nextReviewAt = progress?.nextReviewAt, progress?.attemptCount ?? 0 > 0 {
                    Text("次の復習: \(nextReviewAt.formatted(.dateTime.month().day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 既に知っている語を毎回出題されないための逃げ道と、その取り消し。
                // 片方だけだと「覚えた」にした語を戻せなくなる。
                HStack(spacing: 10) {
                    Button {
                        model.updateStatus(itemId: word.wordId, to: .memorized)
                        Haptics.success()
                    } label: {
                        Label("覚えた", systemImage: "checkmark.circle")
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        model.updateStatus(itemId: word.wordId, to: .review)
                        Haptics.success()
                    } label: {
                        Label("やり直す", systemImage: "arrow.counterclockwise")
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
