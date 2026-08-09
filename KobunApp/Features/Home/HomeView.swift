import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(TabRouter.self) private var router

    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    streakCard
                    if viewModel.dueCount > 0 { reviewCard }
                    startCard
                    masteryCard(title: "単語", summary: viewModel.wordSummary)
                    masteryCard(title: "文法（問題）", summary: viewModel.grammarSummary)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(AppConfig.appDisplayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
        }
        .onAppear { viewModel.configure(context: context) }
    }

    // MARK: - カード

    private var streakCard: some View {
        NavigationLink {
            StudyHistoryView()
        } label: {
            DashboardCard(title: "学習の記録", infoMessage: MetricExplanations.streak) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        StatTile(value: "\(viewModel.streak)日", label: "連続学習", tint: .orange,
                                 infoMessage: MetricExplanations.streak)
                        StatTile(value: "\(viewModel.todayAttempts)", label: "今日の解答", tint: .blue)
                        StatTile(
                            value: viewModel.todayAttempts == 0 ? "—" : "\(Int((viewModel.todayAccuracy * 100).rounded()))%",
                            label: "今日の正答率",
                            tint: .green,
                            infoMessage: MetricExplanations.accuracy
                        )
                    }
                    weekChart
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(UITestID.historyCardLink)
    }

    /// 直近1週間の解答数。学習していない日も0で埋めて描く（飛ばすと横軸が詰まって推移が読めない）
    private var weekChart: some View {
        Chart(viewModel.week) { day in
            BarMark(
                x: .value("日", day.date, unit: .day),
                y: .value("解答数", day.attemptCount)
            )
            .foregroundStyle(day.attemptCount > 0 ? Color.accentColor : Color(.systemGray5))
            .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .frame(height: 70)
    }

    private var reviewCard: some View {
        DashboardCard(title: "今日の復習", infoMessage: MetricExplanations.dueCount) {
            VStack(alignment: .leading, spacing: 12) {
                Text("復習の期限が来ている項目が \(viewModel.dueCount) 件あります。")
                    .font(.subheadline)
                HStack(spacing: 10) {
                    Button {
                        router.startQuiz(QuizRequest(genre: .word, scope: .reviewOnly))
                    } label: {
                        Text("単語を復習").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        router.startQuiz(QuizRequest(genre: .grammar, scope: .reviewOnly))
                    } label: {
                        Text("文法を復習").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var startCard: some View {
        DashboardCard(title: "学習をはじめる") {
            HStack(spacing: 10) {
                Button {
                    router.startQuiz(.word)
                } label: {
                    Label("単語クイズ", systemImage: QuizGenre.word.symbolName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    router.startQuiz(.grammar)
                } label: {
                    Label("文法クイズ", systemImage: QuizGenre.grammar.symbolName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func masteryCard(title: String, summary: ProgressSummary) -> some View {
        DashboardCard(title: "\(title)の習熟度", infoMessage: MetricExplanations.masteryStages) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(summary.total) 件中 \(summary.count(of: .memorized)) 件が「覚えた」")
                    .font(.subheadline)
                MasteryBar(summary: summary)
                MasteryLegend(summary: summary)
            }
        }
    }
}

/// 習熟度の内訳を1本の帯で見せる。数値だけより「どこが厚いか」が一目で分かる。
private struct MasteryBar: View {
    let summary: ProgressSummary

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(LearningStatus.allCases) { status in
                    let count = summary.count(of: status)
                    if count > 0 {
                        Rectangle()
                            .fill(status.barColor)
                            .frame(width: width(for: count, total: geometry.size.width))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 10)
    }

    private func width(for count: Int, total: CGFloat) -> CGFloat {
        guard summary.total > 0 else { return 0 }
        return total * CGFloat(count) / CGFloat(summary.total)
    }
}

private struct MasteryLegend: View {
    let summary: ProgressSummary

    var body: some View {
        HStack(spacing: 12) {
            ForEach(LearningStatus.allCases) { status in
                HStack(spacing: 3) {
                    Circle()
                        .fill(status.barColor)
                        .frame(width: 7, height: 7)
                    Text("\(status.displayName) \(summary.count(of: status))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
