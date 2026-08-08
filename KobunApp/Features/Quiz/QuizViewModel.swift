import Foundation
import SwiftData
import Observation

/// 出題1問ぶん。単語クイズと文法クイズで作り方は違うが、
/// 解答画面から見える形はこの1つに揃える（画面を2つ作らないため）。
struct QuizQuestion: Identifiable {
    /// 進捗のキーでもある（単語なら wordId、文法なら quizId）
    let id: String
    let domain: StudyDomain

    /// 問題の主文。単語クイズなら見出し語、文法クイズなら問題文
    let prompt: String
    /// 読み上げに渡す文字列。単語クイズでのみ使う（歴史的仮名遣いではなく読み）
    let promptReading: String?

    let choices: [String]
    let correctIndex: Int

    /// 解答後に見せる解説
    let explanation: String
    /// 解説の補足（単語クイズなら例文の訳と出典）
    let explanationDetail: String

    /// 結果画面から詳細へ飛ぶためのリンク先
    let wordId: String?
    let grammarId: String?
}

@Observable
@MainActor
final class QuizViewModel {
    static let questionCount = 10
    static let timeLimitPerQuestion: Int = 20

    /// 「未選択のまま時間切れ」を表す `selectedChoiceIndex` の番兵。
    /// 選択肢の添字と衝突しない負値を使う。画面側も同じ値で分岐するので定数にしている。
    static let timeoutSentinel = -1

    private(set) var phase: StudySessionPhase = .notStarted
    private(set) var genre: QuizGenre = .word
    /// 直近に開始したセットの出題対象。画面タイトルと結果の文言を切り替えるのに使う。
    private(set) var scope: QuizScope = .mixed
    private(set) var questions: [QuizQuestion] = []
    private(set) var currentQuestionIndex = 0
    private(set) var selectedChoiceIndex: Int?
    private(set) var remainingSeconds = QuizViewModel.timeLimitPerQuestion
    private(set) var correctAnswerCount = 0

    /// 間違えた問題。結果画面でそのまま復習に使えるよう保持する。
    private(set) var missedQuestions: [QuizQuestion] = []
    /// 時間切れで落とした数（選び間違いと区別する。対策が「速く解く」か「覚え直す」かで変わるため）
    private(set) var timeoutCount = 0
    /// このセットで新たに「覚えた」に到達した数
    private(set) var newlyMemorizedCount = 0
    private var startedAt: Date?
    private(set) var elapsedSeconds = 0

    /// 出題できなかったときにスタート画面へ出す案内。
    /// 「復習を解き終えて期限切れの項目が無くなった」は正常な結果なので、
    /// エラーではなく状況の説明として見せる。
    private(set) var notice: String?

    /// 各ジャンルで出題できる件数。0件のまま始めさせないために表示する
    private(set) var wordPoolCount = 0
    private(set) var grammarPoolCount = 0

    private var content: ContentRepository?
    private var progressRepository: ProgressRepository?
    /// deinit（常にnonisolated）から安全にキャンセルできるよう、actor隔離チェックの対象から外す。
    /// `Task.cancel()` はどのスレッドから呼んでも安全なため、この用途では問題ない。
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressFraction: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }

    func configure(context: ModelContext) {
        guard content == nil else { return }
        content = ContentRepository(context: context)
        progressRepository = ProgressRepository(context: context)
        refreshPoolCounts()
    }

    /// 権利が変わった（試用が切れた・購入した）ときにスタート画面の件数を合わせる
    func refreshPoolCounts() {
        guard let content else { return }
        let rights = Entitlements.shared.rights
        wordPoolCount = content.studyWords(rights: rights).count
        grammarPoolCount = content.studyGrammarQuiz(rights: rights).count
    }

    func start(_ request: QuizRequest) {
        guard let content, let progressRepository else { return }
        genre = request.genre
        scope = request.scope

        let rights = Entitlements.shared.rights
        let progress = progressRepository.allProgress()

        switch request.genre {
        case .word:
            questions = buildWordQuestions(
                pool: content.studyWords(rights: rights),
                scope: request.scope,
                progress: progress
            )
        case .grammar:
            questions = buildGrammarQuestions(
                content: content,
                rights: rights,
                scope: request.scope,
                progress: progress
            )
        }

        currentQuestionIndex = 0
        correctAnswerCount = 0
        selectedChoiceIndex = nil
        missedQuestions = []
        timeoutCount = 0
        newlyMemorizedCount = 0
        elapsedSeconds = 0
        startedAt = .now
        notice = nil

        // 復習を解き終えた直後は期限切れの項目が無くなるため、0問になるのは正常な状態。
        // これを結果画面（.finished）で表示すると「0/0問正解」という意味のない結果が出るうえ、
        // スタート画面へ戻る手段が無くなってクイズを始められなくなる。
        guard !questions.isEmpty else {
            notice = emptyNotice(for: request)
            phase = .notStarted
            GameAudio.shared.stopBGM()
            return
        }

        // 当日の「覚えた」数の基準をここで作る。解答中は増減ぶんしか足し引きしないので、
        // 日付をまたいで復習期限が来た項目や、単語帳から直接変えた分はこの時点で取り込む。
        progressRepository.refreshMasterySnapshot()

        phase = .inProgress
        GameAudio.shared.play(.start)
        GameAudio.shared.startBGM()
        speakPromptIfNeeded()
        startTimer()
    }

    private func emptyNotice(for request: QuizRequest) -> String {
        switch request.scope {
        case .reviewOnly:
            return "復習の期限が来ている項目はありません。おつかれさまでした。"
        case .grammarItem(_, let title):
            return "「\(title)」に解ける問題がありません。"
        case .mixed:
            return request.genre == .word
                ? "出題できる単語がありません。"
                : "出題できる文法問題がありません。"
        }
    }

    // MARK: - 問題の組み立て

    private func buildWordQuestions(
        pool: [WordMaster],
        scope: QuizScope,
        progress: [String: ItemProgress]
    ) -> [QuizQuestion] {
        let ordered: [WordMaster]
        switch scope {
        case .reviewOnly:
            // ホームの「復習がN件あります」から来た場合は、
            // 未学習を混ぜずに期限が来た項目だけを出す
            ordered = StudyQueue.dueItems(items: pool, progress: progress)
        case .mixed, .grammarItem:
            ordered = StudyQueue.prioritize(items: pool, progress: progress)
        }
        return ordered.prefix(Self.questionCount).map { makeWordQuestion(for: $0, pool: pool) }
    }

    private func buildGrammarQuestions(
        content: ContentRepository,
        rights: AccessRights,
        scope: QuizScope,
        progress: [String: ItemProgress]
    ) -> [QuizQuestion] {
        let pool: [GrammarQuizItem]
        switch scope {
        case .grammarItem(let grammarId, _):
            // 特定の文法項目を指定して来た場合も、出題できるのは権利の範囲内だけ
            pool = content.grammarQuiz(forGrammarId: grammarId).filter { rights.canStudy(isFree: $0.isFree) }
        case .mixed, .reviewOnly:
            pool = content.studyGrammarQuiz(rights: rights)
        }

        let ordered: [GrammarQuizItem]
        if case .reviewOnly = scope {
            ordered = StudyQueue.dueItems(items: pool, progress: progress)
        } else {
            ordered = StudyQueue.prioritize(items: pool, progress: progress)
        }
        return ordered.prefix(Self.questionCount).map(makeGrammarQuestion(for:))
    }

    /// 単語クイズ: 見出し語を見せて、意味の4択を選ばせる。
    private func makeWordQuestion(for word: WordMaster, pool: [WordMaster]) -> QuizQuestion {
        // 同じ品詞の語から選べると選択肢が締まる（品詞の違いだけで答えを絞れてしまうのを防ぐ）。
        // 足りなければ品詞を問わず埋める。
        let others = pool.filter { $0.wordId != word.wordId }
        let choices = QuizChoiceBuilder.build(
            correctMeaning: word.meaning,
            samePartOfSpeech: others.filter { $0.partOfSpeech == word.partOfSpeech }.shuffled().map(\.meaning),
            others: others.shuffled().map(\.meaning)
        )

        let detail = [word.exampleTranslation, word.source.isEmpty ? "" : "（\(word.source)）"]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return QuizQuestion(
            id: word.wordId,
            domain: .word,
            prompt: word.word,
            promptReading: word.reading,
            choices: choices.options,
            correctIndex: choices.correctIndex,
            explanation: word.example,
            explanationDetail: detail,
            wordId: word.wordId,
            grammarId: nil
        )
    }

    /// 文法クイズ: 同梱の問題バンクをそのまま出す。
    /// 選択肢はデータ側でも散らしてあるが、繰り返し解くと位置を覚えてしまうので毎回並べ替える。
    private func makeGrammarQuestion(for item: GrammarQuizItem) -> QuizQuestion {
        let correct = item.correctChoice
        let shuffled = item.choices.shuffled()
        // 同じ文言が複数あるデータは build_seed.py が弾いているので、firstIndex で正しい位置が取れる。
        // 万一取れなくても落とさず、元の並びのまま出す。
        let correctIndex = shuffled.firstIndex(of: correct) ?? item.answerIndex

        return QuizQuestion(
            id: item.quizId,
            domain: .grammar,
            prompt: item.question,
            promptReading: nil,
            choices: shuffled.isEmpty ? item.choices : shuffled,
            correctIndex: correctIndex,
            explanation: item.explanation,
            explanationDetail: "",
            wordId: nil,
            grammarId: item.grammarId
        )
    }

    // MARK: - 解答

    func selectAnswer(_ index: Int) {
        guard phase == .inProgress, selectedChoiceIndex == nil, let question = currentQuestion else { return }
        timerTask?.cancel()
        selectedChoiceIndex = index

        let isCorrect = index == question.correctIndex
        if isCorrect { correctAnswerCount += 1 }
        GameAudio.shared.play(isCorrect ? .wordComplete : .miss)
        record(question: question, isCorrect: isCorrect)
    }

    /// 制限時間切れ（未回答）は不正解として記録する
    private func handleTimeout() {
        guard phase == .inProgress, let question = currentQuestion, selectedChoiceIndex == nil else { return }
        selectedChoiceIndex = Self.timeoutSentinel
        timeoutCount += 1
        GameAudio.shared.play(.miss)
        record(question: question, isCorrect: false)
    }

    private func record(question: QuizQuestion, isCorrect: Bool) {
        guard let progressRepository else { return }
        let outcome = progressRepository.recordAnswer(
            itemId: question.id,
            domain: question.domain,
            isCorrect: isCorrect
        )
        if outcome.reachedMemorized { newlyMemorizedCount += 1 }
        if !isCorrect { missedQuestions.append(question) }
    }

    func goToNextQuestion() {
        timerTask?.cancel()
        guard currentQuestionIndex + 1 < questions.count else {
            if let startedAt {
                elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(startedAt)))
            }
            phase = .finished
            GameAudio.shared.stopBGM()
            // 1問ごとの保存は待ち時間になるのでやめ、区切りでまとめて書き出す
            progressRepository?.save()
            GameAudio.shared.play(resultSummary.accuracyPercent >= 75 ? .fanfare : .gameOver)
            return
        }
        currentQuestionIndex += 1
        selectedChoiceIndex = nil
        speakPromptIfNeeded()
        startTimer()
    }

    /// 単語クイズでは問題文（＝古語）を読み上げる。音は意味の記憶を助けるため。
    /// 文法クイズの問題文は長い説明文なので読み上げない。
    private func speakPromptIfNeeded() {
        guard genre == .word, let reading = currentQuestion?.promptReading else { return }
        WordPronouncer.shared.speak(reading: reading)
    }

    var resultSummary: QuizResultSummary {
        QuizResultSummary(
            genre: genre,
            scope: scope,
            correctCount: correctAnswerCount,
            totalCount: questions.count,
            timeoutCount: timeoutCount,
            newlyMemorizedCount: newlyMemorizedCount,
            elapsedSeconds: elapsedSeconds,
            missed: missedQuestions.map {
                QuizResultSummary.MissedItem(
                    id: $0.id,
                    title: $0.prompt,
                    answer: $0.choices.indices.contains($0.correctIndex) ? $0.choices[$0.correctIndex] : "",
                    wordId: $0.wordId,
                    grammarId: $0.grammarId
                )
            }
        )
    }

    /// 進行中のセットを破棄してスタート画面に戻す。
    /// これが無いと、始めてしまったら最後まで解くか時間切れを待つしか抜ける手段がない。
    func abortSession() { returnToStart() }

    /// 結果画面からスタート画面へ戻す。
    /// 結果を見たあと別の出題で解き直せるよう、必ず戻り道を用意しておく。
    func returnToStart() {
        timerTask?.cancel()
        timerTask = nil
        GameAudio.shared.stopBGM()
        WordPronouncer.shared.stop()
        progressRepository?.save()
        questions = []
        currentQuestionIndex = 0
        selectedChoiceIndex = nil
        correctAnswerCount = 0
        notice = nil
        phase = .notStarted
        refreshPoolCounts()
    }

    /// 別タブへ移動した・アプリが背面に回ったときに制限時間の消費を止める。
    /// 止めないと画面を見ていない間に時間切れになり、戻ったら勝手に不正解が記録されている。
    func suspendTimer() {
        timerTask?.cancel()
        timerTask = nil
        GameAudio.shared.stopBGM()
        WordPronouncer.shared.stop()
        // 背面に回されたまま終了されても解答が消えないよう、ここで書き出しておく
        progressRepository?.save()
    }

    /// 画面に戻ったときに、残り時間を引き継いで計測を再開する
    func resumeTimer() {
        guard phase == .inProgress else { return }
        GameAudio.shared.startBGM()
        guard selectedChoiceIndex == nil, timerTask == nil else { return }
        runTimer()
    }

    private func startTimer() {
        remainingSeconds = Self.timeLimitPerQuestion
        runTimer()
    }

    private func runTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while remainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remainingSeconds -= 1
            }
            handleTimeout()
        }
    }

    deinit {
        timerTask?.cancel()
    }
}

/// 結果画面に渡す集計。SwiftData のオブジェクトを持ち回らず値だけを渡す
struct QuizResultSummary {
    struct MissedItem: Identifiable {
        let id: String
        let title: String
        let answer: String
        let wordId: String?
        let grammarId: String?
    }

    let genre: QuizGenre
    let scope: QuizScope
    let correctCount: Int
    let totalCount: Int
    let timeoutCount: Int
    let newlyMemorizedCount: Int
    let elapsedSeconds: Int
    let missed: [MissedItem]

    var accuracyPercent: Int {
        totalCount == 0 ? 0 : Int((Double(correctCount) / Double(totalCount) * 100).rounded())
    }

    var grade: String {
        switch accuracyPercent {
        case 90...: return "S"
        case 75..<90: return "A"
        case 60..<75: return "B"
        case 40..<60: return "C"
        default: return "D"
        }
    }
}
