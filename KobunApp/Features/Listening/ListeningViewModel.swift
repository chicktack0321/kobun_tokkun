import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ListeningViewModel {
    private(set) var items: [ListeningItem] = []
    /// 絞り込みを外したときに聞ける語数。「0語」の理由を言い分けるのに使う
    private(set) var unfilteredCount = 0

    /// 習熟段階での絞り込み（nil はすべて）。
    /// 「要復習だけ流す」が聞き流しの主な使い道になる。
    var statusFilter: LearningStatus? = StudySettings.listeningStatusFilter {
        didSet {
            guard statusFilter != oldValue else { return }
            StudySettings.listeningStatusFilter = statusFilter
            rebuild()
        }
    }

    var isShuffled: Bool = StudySettings.listeningShuffle {
        didSet {
            guard isShuffled != oldValue else { return }
            StudySettings.listeningShuffle = isShuffled
            rebuild()
        }
    }

    var readsExample: Bool = StudySettings.listeningReadsExample {
        didSet {
            guard readsExample != oldValue else { return }
            StudySettings.listeningReadsExample = readsExample
            AudioPlaybackManager.shared.readsExample = readsExample
            // 読み上げる中身が変わるので、再生中なら組み立て直して現在位置から続ける
            if AudioPlaybackManager.shared.state != .stopped {
                restartFromCurrent()
            }
        }
    }

    /// 選べる速さ。連続スライダーだと「今どのくらいなのか」「標準はどこか」が分からないため、
    /// 段階を決め打ちにして倍率をそのまま見せる。
    ///
    /// 2.0倍は外している。合成音声が潰れて語の聞き分けができず、聞き流しの用をなさないため。
    static let speedOptions: [Double] = [0.8, 1.0, 1.2, 1.5]

    var speed: Double = ListeningViewModel.nearestSpeedOption(to: StudySettings.listeningSpeed) {
        didSet {
            guard speed != oldValue else { return }
            StudySettings.listeningSpeed = speed
            // 速度は次に読む文から効く。読み上げ中の文を切って作り直すと聞いていた語が飛ぶ
            AudioPlaybackManager.shared.speedMultiplier = speed
        }
    }

    /// 保存済みの値が選択肢に無い場合（スライダーだったころの 1.1 など）に一番近い段階へ寄せる。
    /// そのままだとセグメントがどれも選ばれていない状態になり、今の速さが読み取れない。
    private static func nearestSpeedOption(to value: Double) -> Double {
        speedOptions.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1.0
    }

    private var content: ContentRepository?
    private var progressRepository: ProgressRepository?

    func configure(context: ModelContext) {
        if content == nil {
            content = ContentRepository(context: context)
            progressRepository = ProgressRepository(context: context)
        }
        AudioPlaybackManager.shared.readsExample = readsExample
        AudioPlaybackManager.shared.speedMultiplier = speed
        rebuild()
    }

    func rebuild() {
        guard let content, let progressRepository else { return }
        let all = content.allWords()
        unfilteredCount = all.count

        let filtered = StudyQueue.filter(
            items: all,
            byStatus: statusFilter,
            progress: progressRepository.allProgress()
        )
        let ordered = isShuffled ? filtered.shuffled() : filtered
        items = ordered.map {
            ListeningItem(
                id: $0.wordId,
                word: $0.word,
                reading: $0.reading,
                meaning: $0.meaning,
                example: $0.example,
                exampleTranslation: $0.exampleTranslation
            )
        }
    }

    /// 設定を変えたときに、いま聞いている語から再生し直す。
    /// 先頭に戻すと「例文も読む」に切り替えるたびに最初からになってしまう。
    private func restartFromCurrent() {
        let player = AudioPlaybackManager.shared
        player.play(items: items, startAt: player.currentIndex)
    }

    func play(from index: Int = 0) {
        guard !items.isEmpty else { return }
        AudioPlaybackManager.shared.play(items: items, startAt: index)
    }
}
