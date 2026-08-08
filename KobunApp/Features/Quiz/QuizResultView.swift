import SwiftUI
import SwiftData

struct QuizResultView: View {
    let summary: QuizResultSummary
    let onRestart: () -> Void

    /// 紙吹雪は表示時に1回だけ弾かせる。値が変わったときに発生する仕組みなので、
    /// 0のままだと出ず、毎回変える必要もない（この画面は結果ごとに作り直される）。
    @State private var celebration = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreCard

                if summary.newlyMemorizedCount > 0 {
                    DashboardCard(title: "覚えた", infoMessage: MetricExplanations.masteryStages) {
                        Text("このセットで \(summary.newlyMemorizedCount) 件が「覚えた」に到達しました。")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !summary.missed.isEmpty {
                    missedCard
                }

                Button(action: onRestart) {
                    Text("クイズの選択に戻る")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        // 上位の成績のときだけ祝う。毎回出すと達成の合図として意味を失う
        .overlay(alignment: .top) {
            ConfettiView(trigger: celebration)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard summary.accuracyPercent >= 90 else { return }
            celebration += 1
            Haptics.celebrate()
        }
    }

    private var scoreCard: some View {
        DashboardCard(title: "結果") {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(summary.grade)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(summary.correctCount) / \(summary.totalCount) 問正解")
                            .font(.title3.bold())
                        Text("正答率 \(summary.accuracyPercent)%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    StatTile(value: "\(summary.elapsedSeconds)秒", label: "所要時間", tint: .blue)
                    // 時間切れは選び間違いと分けて出す。対策が「速く解く」か「覚え直す」かで変わる
                    StatTile(value: "\(summary.timeoutCount)", label: "時間切れ", tint: .orange)
                }
            }
        }
    }

    private var gradeColor: Color {
        switch summary.grade {
        case "S", "A": return .green
        case "B": return .blue
        case "C": return .orange
        default: return .red
        }
    }

    private var missedCard: some View {
        DashboardCard(title: "間違えた問題") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(summary.missed) { item in
                    NavigationLink {
                        MissedItemDestination(item: item)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .multilineTextAlignment(.leading)
                                if !item.answer.isEmpty {
                                    Text("正解: \(item.answer)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    if item.id != summary.missed.last?.id { Divider() }
                }
            }
        }
    }
}

/// 間違えた問題から、対応する単語詳細・文法詳細へ送る。
/// 結果画面で終わらせず「その場で確認できる」ようにするための導線。
private struct MissedItemDestination: View {
    let item: QuizResultSummary.MissedItem
    @Environment(\.modelContext) private var context

    var body: some View {
        if let wordId = item.wordId, let word = ContentRepository(context: context).word(id: wordId) {
            WordDetailView(word: word)
        } else if let grammarId = item.grammarId,
                  let grammar = ContentRepository(context: context).grammar(id: grammarId) {
            GrammarDetailView(grammar: grammar)
        } else {
            // データ更新で項目が消えた場合（進捗は残るが本体は消えうる）
            ContentUnavailableView("項目が見つかりません", systemImage: "questionmark.circle")
        }
    }
}
