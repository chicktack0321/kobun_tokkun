import SwiftUI
import SwiftData
import Charts

/// ホームのミニグラフから開く学習履歴の詳細。期間を切り替えて推移を見る。
struct StudyHistoryView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = StudyHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("期間", selection: Bindable(viewModel).range) {
                    ForEach(HistoryRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                summaryCard
                attemptsCard
                masteryCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("学習の記録")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.configure(context: context) }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(viewModel.totalAttempts)", label: "解答数", tint: .blue)
            StatTile(
                value: viewModel.totalAttempts == 0 ? "—" : "\(Int((viewModel.accuracy * 100).rounded()))%",
                label: "正答率",
                tint: .green,
                infoMessage: MetricExplanations.accuracy
            )
            StatTile(value: "\(viewModel.streak)日", label: "連続学習", tint: .orange,
                     infoMessage: MetricExplanations.streak)
        }
    }

    private var attemptsCard: some View {
        DashboardCard(title: "解答数の推移") {
            Chart(viewModel.series) { day in
                BarMark(
                    x: .value("日", day.date, unit: viewModel.range.chartUnit),
                    y: .value("解答数", day.attemptCount)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(3)
            }
            .frame(height: 160)
        }
    }

    /// 覚えた数は「その日の残高」なので折れ線で描く。棒にすると増分と誤解される。
    private var masteryCard: some View {
        DashboardCard(title: "「覚えた」の推移", infoMessage: MetricExplanations.masteryStages) {
            Chart(viewModel.series) { day in
                LineMark(
                    x: .value("日", day.date, unit: viewModel.range.chartUnit),
                    y: .value("単語", day.masteredWordCount)
                )
                .foregroundStyle(by: .value("種別", "単語"))

                LineMark(
                    x: .value("日", day.date, unit: viewModel.range.chartUnit),
                    y: .value("文法", day.masteredGrammarCount)
                )
                .foregroundStyle(by: .value("種別", "文法"))
            }
            .chartLegend(position: .bottom)
            .frame(height: 160)
        }
    }
}
