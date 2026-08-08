import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ListeningViewModel {
    private(set) var items: [ListeningItem] = []
    /// 出題範囲の制限で聞ける語が減っているか（案内を出すかの判断に使う）
    private(set) var isLimited = false
    private(set) var totalWordCount = 0

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

    var speed: Double = StudySettings.listeningSpeed {
        didSet {
            guard speed != oldValue else { return }
            StudySettings.listeningSpeed = speed
            // 速度は次に読む文から効く。読み上げ中の文を切って作り直すと聞いていた語が飛ぶ
            AudioPlaybackManager.shared.speedMultiplier = speed
        }
    }

    private var content: ContentRepository?

    func configure(context: ModelContext) {
        if content == nil {
            content = ContentRepository(context: context)
        }
        AudioPlaybackManager.shared.readsExample = readsExample
        AudioPlaybackManager.shared.speedMultiplier = speed
        rebuild()
    }

    func rebuild() {
        guard let content else { return }
        let rights = Entitlements.shared.rights
        let all = content.allWords()
        let pool = content.studyWords(rights: rights)

        totalWordCount = all.count
        isLimited = pool.count < all.count

        let ordered = isShuffled ? pool.shuffled() : pool
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
        let index = player.currentIndex
        player.play(items: items, startAt: index)
    }

    func play(from index: Int = 0) {
        guard !items.isEmpty else { return }
        AudioPlaybackManager.shared.play(items: items, startAt: index)
    }
}
