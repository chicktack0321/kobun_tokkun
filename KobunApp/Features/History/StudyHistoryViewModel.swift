import Foundation
import SwiftData
import Observation

enum HistoryRange: Int, CaseIterable, Identifiable {
    case twoWeeks = 14
    case month = 30
    case threeMonths = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .twoWeeks: return "2週間"
        case .month: return "1か月"
        case .threeMonths: return "3か月"
        }
    }

    /// 3か月を日ごとに描くと棒が1px以下になって読めないため、週単位にまとめる
    var aggregatesWeekly: Bool { self == .threeMonths }

    var chartUnit: Calendar.Component { aggregatesWeekly ? .weekOfYear : .day }
}

@Observable
@MainActor
final class StudyHistoryViewModel {
    var range: HistoryRange = .twoWeeks {
        didSet {
            guard range != oldValue else { return }
            reload()
        }
    }

    private(set) var series: [DailyStudy] = []
    private(set) var totalAttempts = 0
    private(set) var accuracy: Double = 0
    private(set) var streak = 0

    private var progressRepository: ProgressRepository?

    func configure(context: ModelContext) {
        if progressRepository == nil {
            progressRepository = ProgressRepository(context: context)
        }
        reload()
    }

    func reload(now: Date = .now) {
        guard let progressRepository else { return }

        // 解答を経ない習熟度の変化（期限切れ、単語帳での操作）を当日ぶんに取り込んでから描く
        progressRepository.refreshMasterySnapshot(at: now)

        let logs = progressRepository.logsForStreak(today: now)
        let daily = StudyHistory.series(logs: logs, days: range.rawValue, endingOn: now)

        series = range.aggregatesWeekly ? StudyHistory.weekly(from: daily) : daily
        // 集計は日次の系列から取る。週にまとめた後だと丸めの影響を受ける
        totalAttempts = StudyHistory.totalAttempts(in: daily)
        accuracy = StudyHistory.overallAccuracy(in: daily)
        streak = StudyHistory.currentStreak(logs: logs, today: now)
    }
}
