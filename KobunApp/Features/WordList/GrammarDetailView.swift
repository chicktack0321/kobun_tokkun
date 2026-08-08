import SwiftUI
import SwiftData

struct GrammarDetailView: View {
    let grammar: GrammarMaster
    /// 一覧から開いたときは共有し、クイズ結果から開いたときはこの画面で作る（既定値で省略可能にする）
    var viewModel: LibraryViewModel? = nil

    @Environment(\.modelContext) private var context
    @Environment(TabRouter.self) private var router
    @State private var ownViewModel = LibraryViewModel()

    private var model: LibraryViewModel { viewModel ?? ownViewModel }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if !grammar.connection.isEmpty || !grammar.conjugation.isEmpty { formCard }
                explanationCard
                if !grammar.example.isEmpty { exampleCard }
                practiceCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(grammar.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil { ownViewModel.configure(context: context) }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(grammar.title)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
            Text(grammar.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(grammar.category.displayName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    /// 接続と活用は表形式で並べる。文法の問題はこの2つで決まることが多く、
    /// 解説文に埋もれると参照しづらい。
    private var formCard: some View {
        DashboardCard(title: "接続と活用") {
            VStack(alignment: .leading, spacing: 10) {
                if !grammar.connection.isEmpty {
                    labeled("接続", grammar.connection)
                }
                if !grammar.conjugation.isEmpty {
                    labeled("活用", grammar.conjugation)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private var explanationCard: some View {
        DashboardCard(title: "解説") {
            Text(grammar.explanation)
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var exampleCard: some View {
        DashboardCard(title: "例文") {
            VStack(alignment: .leading, spacing: 8) {
                Text(grammar.example)
                    .font(.body)
                Text(grammar.exampleTranslation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !grammar.source.isEmpty {
                    Text("出典: \(grammar.source)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// この項目だけを出題するクイズへの導線。
    /// 解説を読んだ直後に確かめられることが、文法の定着では単語より効く。
    private var practiceCard: some View {
        let quizCount = model.grammarQuizCounts[grammar.grammarId] ?? 0
        let status = model.grammarStatus[grammar.grammarId] ?? .notStudied

        return DashboardCard(title: "この項目の習熟度", infoMessage: MetricExplanations.grammarMastery) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: status.symbolName)
                        .foregroundStyle(status.tint)
                    Text(status.displayName)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("問題 \(quizCount) 問")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if quizCount > 0 {
                    Button {
                        router.startQuiz(QuizRequest(
                            genre: .grammar,
                            scope: .grammarItem(grammarId: grammar.grammarId, title: grammar.title)
                        ))
                    } label: {
                        Label("この項目の問題を解く", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("この項目には問題がありません。解説のみの項目です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
