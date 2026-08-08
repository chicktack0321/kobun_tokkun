import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabRouter.self) private var router

    @State private var viewModel = QuizViewModel()
    @State private var entitlements = Entitlements.shared

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .notStarted:
                    QuizStartView(viewModel: viewModel)
                case .inProgress:
                    QuizPlayView(viewModel: viewModel)
                case .finished:
                    QuizResultView(summary: viewModel.resultSummary) {
                        viewModel.returnToStart()
                    }
                }
            }
            .navigationTitle(viewModel.phase == .notStarted ? "4択クイズ" : viewModel.scope.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SoundToggleButton(isSessionActive: viewModel.phase == .inProgress)
                }
                if viewModel.phase == .inProgress {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("やめる") { viewModel.abortSession() }
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(context: context)
            // 効果音の波形合成を先に済ませておく。スタートを押した流れの中で行うと、
            // 開始のたびに待たされる（参考元で実際に起きていた）。
            GameAudio.shared.warmUp()
            // ホーム等から「このクイズを始める」と指定されて来た場合は自動で開始する
            if let request = router.consumePendingQuizRequest() {
                viewModel.start(request)
            } else {
                viewModel.resumeTimer()
            }
        }
        .onDisappear { viewModel.suspendTimer() }
        .onChange(of: scenePhase) { _, newPhase in
            // 背面に回っている間に制限時間が減り続けると、戻ったときに
            // 見ていない問題が不正解として記録されている
            if newPhase == .active { viewModel.resumeTimer() } else { viewModel.suspendTimer() }
        }
        .onChange(of: entitlements.rights) { _, _ in viewModel.refreshPoolCounts() }
    }
}

// MARK: - スタート画面

private struct QuizStartView: View {
    @Bindable var viewModel: QuizViewModel
    @State private var entitlements = Entitlements.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let notice = viewModel.notice {
                    Text(notice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                genreCard(
                    genre: .word,
                    count: viewModel.wordPoolCount,
                    caption: "見出し語を見て、意味を4択から選びます。"
                )
                genreCard(
                    genre: .grammar,
                    count: viewModel.grammarPoolCount,
                    caption: "助動詞・助詞・敬語の用法を4択で答えます。"
                )

                DashboardCard(title: "出題のしかた", infoMessage: MetricExplanations.dueCount) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("1回 \(QuizViewModel.questionCount) 問・1問 \(QuizViewModel.timeLimitPerQuestion) 秒",
                              systemImage: "timer")
                        Label("復習の期限が来た項目から先に出します", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if !entitlements.hasFullAccess {
                    LockedRangeNotice()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func genreCard(genre: QuizGenre, count: Int, caption: String) -> some View {
        DashboardCard(title: genre.title) {
            VStack(alignment: .leading, spacing: 12) {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("出題対象 \(count) 件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    viewModel.start(QuizRequest(genre: genre, scope: .mixed))
                } label: {
                    Label("はじめる", systemImage: genre.symbolName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
            }
        }
    }
}

/// 試用終了後・未購入のときに、何が制限されているのかを説明する。
/// 「使えなくなった」ではなく「出題範囲が狭まっている」ことを明示するために出す。
struct LockedRangeNotice: View {
    var body: some View {
        DashboardCard(title: "出題範囲について", infoMessage: MetricExplanations.freeRange) {
            VStack(alignment: .leading, spacing: 10) {
                Text("いまは無料範囲の項目だけが出題されます。単語帳と文法解説はすべて読めます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    PaywallView()
                } label: {
                    Label("すべての単語・文法を解放する", systemImage: "lock.open")
                }
                .font(.subheadline)
            }
        }
    }
}

// MARK: - 出題中

private struct QuizPlayView: View {
    @Bindable var viewModel: QuizViewModel

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.progressFraction)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 20) {
                    header
                    if let question = viewModel.currentQuestion {
                        prompt(question)
                        choices(question)
                        if viewModel.selectedChoiceIndex != nil {
                            feedback(question)
                        }
                    }
                }
                .padding()
            }

            if viewModel.selectedChoiceIndex != nil {
                Button {
                    viewModel.goToNextQuestion()
                } label: {
                    Text(viewModel.currentQuestionIndex + 1 < viewModel.questions.count ? "次の問題へ" : "結果を見る")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        HStack {
            Text("\(viewModel.currentQuestionIndex + 1) / \(viewModel.questions.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Label("\(viewModel.remainingSeconds)", systemImage: "timer")
                .font(.subheadline.monospacedDigit())
                // 残り5秒を切ったら色を変える。数字だけだと切迫に気づかない
                .foregroundStyle(viewModel.remainingSeconds <= 5 ? .red : .secondary)
        }
    }

    @ViewBuilder
    private func prompt(_ question: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            Text(question.prompt)
                // 単語は大きく1語だけ、文法は説明文なので本文サイズにする
                .font(question.domain == .word ? .largeTitle.bold() : .title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if question.domain == .word, let reading = question.promptReading, reading != question.prompt {
                Text(reading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if question.domain == .word, let reading = question.promptReading {
                Button {
                    WordPronouncer.shared.speak(reading: reading)
                } label: {
                    Label("読み上げ", systemImage: "speaker.wave.2")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private func choices(_ question: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    viewModel.selectAnswer(index)
                } label: {
                    HStack {
                        Text(choice)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let symbol = symbolName(for: index, question: question) {
                            Image(systemName: symbol)
                        }
                    }
                    .padding()
                    .background(background(for: index, question: question), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedChoiceIndex != nil)
            }
        }
    }

    /// 解答後は「選んだもの」と「正解」の両方を色で示す。
    /// 正解だけを示すと、自分が何を選んだのか分からないまま次へ進んでしまう。
    private func background(for index: Int, question: QuizQuestion) -> Color {
        guard let selected = viewModel.selectedChoiceIndex else { return Color(.secondarySystemGroupedBackground) }
        if index == question.correctIndex { return .green.opacity(0.25) }
        if index == selected { return .red.opacity(0.25) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func symbolName(for index: Int, question: QuizQuestion) -> String? {
        guard let selected = viewModel.selectedChoiceIndex else { return nil }
        if index == question.correctIndex { return "checkmark.circle.fill" }
        if index == selected { return "xmark.circle.fill" }
        return nil
    }

    /// 解答の見出し。時間切れを不正解と同じ文言にすると、
    /// 「分からなかった」のか「間に合わなかった」のかが本人にも分からなくなる。
    private func feedbackTitle(_ question: QuizQuestion) -> String {
        // 呼び出し元が selectedChoiceIndex != nil を確かめてから描いている
        guard let selected = viewModel.selectedChoiceIndex else { return "" }
        if selected == QuizViewModel.timeoutSentinel { return "時間切れ" }
        return selected == question.correctIndex ? "正解" : "不正解"
    }

    private func feedback(_ question: QuizQuestion) -> some View {
        DashboardCard(title: feedbackTitle(question)) {
            VStack(alignment: .leading, spacing: 8) {
                if !question.explanation.isEmpty {
                    Text(question.explanation)
                        .font(.subheadline)
                }
                if !question.explanationDetail.isEmpty {
                    Text(question.explanationDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
