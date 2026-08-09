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

                StatusFilterCard(
                    title: "出題する範囲",
                    selection: Bindable(viewModel).statusFilter
                )

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

/// 習熟段階での絞り込み。クイズと聞き流しで同じ見た目・同じ並びにするため共通にしている。
/// 「要復習だけ解き直す」「未学習だけ進める」がこの2画面での主な使い道。
struct StatusFilterCard: View {
    let title: String
    @Binding var selection: LearningStatus?

    var body: some View {
        DashboardCard(title: title, infoMessage: MetricExplanations.masteryStages) {
            Picker(title, selection: $selection) {
                Text("すべて").tag(LearningStatus?.none)
                ForEach(LearningStatus.allCases) { status in
                    Text(status.displayName).tag(LearningStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
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

    /// スワイプで送っている最中の見た目のずれ。送り出しのアニメーションにも使う
    @State private var dragOffset: CGFloat = 0
    /// 送り出しの最中に二重で送らないための鍵
    @State private var isAdvancing = false

    private var hasAnswered: Bool { viewModel.selectedChoiceIndex != nil }

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
                        if hasAnswered {
                            feedback(question)
                        }
                    }
                }
                .padding()
            }
            // `offset` はレイアウトを動かさないので、続く `clipped` は元の枠で切ってくれる。
            // これが無いと、送り出したカードが進捗バーや下のボタンの上に描かれる。
            .offset(y: dragOffset)
            .clipped()

            if hasAnswered { advanceBar }
        }
        .background(Color(.systemGroupedBackground))
        // 次の解答で震わせるので、手が空いているこのタイミングで温めておく。
        // 発火の直前に用意すると Taptic Engine が冷えた状態から起動され、一拍遅れて震える。
        .onChange(of: viewModel.currentQuestionIndex, initial: true) { _, _ in
            Haptics.prepare()
        }
        // 解答が確定した瞬間に手応えを返す。正解は1回、不正解は3回。
        // 画面を見ずに解いていても正誤が分かるよう、はっきり差をつけている。
        .onChange(of: viewModel.selectedChoiceIndex) { _, selected in
            guard let selected, let question = viewModel.currentQuestion else { return }
            if selected == question.correctIndex {
                Haptics.success()
            } else {
                // 時間切れ（番兵 -1）もここに来る。答えられなかったことは伝わってよい
                Haptics.failure()
            }
        }
    }

    /// 解答後に出る送りの操作。
    ///
    /// スワイプの判定をこの帯だけに付けているのは、上のカード領域が `ScrollView` だから。
    /// 画面全体に付けると、文法問題のように中身が画面に収まらないときに、
    /// 上へスクロールしたつもりが次の問題へ飛んでしまう。
    /// 解答後の親指はこの帯の上にあるので、片手で送れるという狙いは保てる。
    private var advanceBar: some View {
        VStack(spacing: 6) {
            Button {
                advance()
            } label: {
                Text(viewModel.currentQuestionIndex + 1 < viewModel.questions.count ? "次の問題へ" : "結果を見る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Label("上にスワイプでも進めます", systemImage: "chevron.up")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        // ボタンの上だけでなく、周りの余白からでも送れるようにする
        .contentShape(Rectangle())
        .gesture(swipeToAdvance)
    }

    /// 解答後だけ、上へのドラッグで次の問題へ送る。
    /// 解答前に効かせると、選択肢を読まないまま飛ばせてしまう。
    private var swipeToAdvance: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard hasAnswered, !isAdvancing else { return }
                // 上方向にだけ付いていく。下へは動かさない
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                guard hasAnswered, !isAdvancing else { return }
                // 指を離した時点の勢いも見る。ゆっくり長く引かなくても送れるようにする
                let flicked = value.predictedEndTranslation.height < -120
                if value.translation.height < -60 || flicked {
                    advance()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    /// いま出ている問題を上へ送り出し、次の問題を下から入れる。
    ///
    /// SwiftUI の transition に任せると、`dragOffset` を0に戻した時点でカードが
    /// 元の位置へ瞬間的に戻り、そこから改めて上へ動く。指を離した位置から
    /// 続けて抜けていくように見せるため、送り出しと入れ替えを自分で順に動かす。
    private func advance() {
        guard !isAdvancing else { return }
        isAdvancing = true
        WordPronouncer.shared.stop()

        // 1. 指を離した位置から、そのまま上へ抜ける
        withAnimation(.easeIn(duration: Self.advanceDuration)) {
            dragOffset = -Self.offscreenDistance
        } completion: {
            // 2. 画面外にいる間に問題を入れ替え、下へ回り込ませる（ここは動かして見せない）
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                viewModel.goToNextQuestion()
                dragOffset = Self.offscreenDistance
            }

            // 3. 下から入ってくる。同じ描画のタイミングで指定すると
            //    2の位置移動ごとアニメーションになってしまうため、1回ずらす
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: Self.advanceDuration)) {
                    dragOffset = 0
                }
                isAdvancing = false
            }
        }
    }

    /// カードを完全に隠すのに十分な距離。表示領域は切り取っているのでこれ以上は見えない
    private static let offscreenDistance: CGFloat = 700

    /// 送り出しと入れ替えのそれぞれにかける時間。合計はこの倍になる。
    /// テンポを優先して短めにしてある。長いと押してから待たされる感じが出る。
    private static let advanceDuration: Double = 0.12

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
                // UIテストから選択肢だけを狙うための識別子。
                // 添字（element(boundBy:)）で拾うと、ツールバーやタブバーのボタンまで
                // 同じ並びに入るため、選択肢のつもりでタブを押す事故が起きる。
                .accessibilityIdentifier(UITestID.quizChoice)
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
