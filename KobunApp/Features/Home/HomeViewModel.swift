import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HomeViewModel {
    /// 直近1週間の日次データ（ミニグラフ用）
    private(set) var week: [DailyStudy] = []
    private(set) var streak = 0
    private(set) var todayAttempts = 0
    private(set) var todayAccuracy: Double = 0

    private(set) var wordSummary: ProgressSummary = .empty
    private(set) var grammarSummary: ProgressSummary = .empty

    /// 復習期限が来ている件数。単語と文法問題を合わせた数
    private(set) var dueCount = 0

    private var content: ContentRepository?
    private var progressRepository: ProgressRepository?

    func configure(context: ModelContext) {
        if content == nil {
            content = ContentRepository(context: context)
            progressRepository = ProgressRepository(context: context)
        }
        reload()
    }

    func reload(now: Date = .now) {
        guard let content, let progressRepository else { return }

        // 習熟度は解答を経ない変更（日付をまたいだ期限切れ、単語帳での「覚えた」操作）でも動く。
        // ホームを開いた時点で焼き直しておかないと、推移グラフの当日分が古いままになる。
        progressRepository.refreshMasterySnapshot(at: now)

        let logs = progressRepository.logsForStreak(today: now)
        week = StudyHistory.series(logs: logs, days: 7, endingOn: now)
        streak = StudyHistory.currentStreak(logs: logs, today: now)

        let today = progressRepository.todayLog(date: now)
        todayAttempts = today?.attemptCount ?? 0
        todayAccuracy = today?.accuracy ?? 0

        let words = content.allWords()
        let quizItems = content.allGrammarQuiz()
        wordSummary = progressRepository.summarize(itemIds: words.map(\.wordId))
        grammarSummary = progressRepository.summarize(itemIds: quizItems.map(\.quizId))

        // 復習の件数は「出題できる範囲」で数える。閲覧できる全項目で数えると、
        // 押しても出題されない項目まで含まれて件数と実際の出題数が食い違う。
        let rights = Entitlements.shared.rights
        let progress = progressRepository.allProgress()
        dueCount = StudyQueue.dueCount(items: content.studyWords(rights: rights), progress: progress, now: now)
            + StudyQueue.dueCount(items: content.studyGrammarQuiz(rights: rights), progress: progress, now: now)
    }
}
