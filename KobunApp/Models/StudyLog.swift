import Foundation
import SwiftData

/// 日次の学習サマリー（解答数・正答率のローカル保存）。`ItemProgress` とは別テーブルとし、
/// 「その日いくつ・何%正解したか」を集計コストなしで即座にグラフ表示できるようにする。
@Model
final class StudyLog {
    /// 日付キー（時刻を切り捨てた日単位）
    @Attribute(.unique) var date: Date

    /// 延べ解答項目数（同じ項目を複数回復習した場合もその都度カウント）
    var studiedItemCount: Int

    var correctCount: Int
    var attemptCount: Int

    /// その日の最後の解答時点で「覚えた」だった数。
    /// 習熟度の推移グラフは過去に遡って再計算できない（現在の状態しか残らない）ため、
    /// 解答のたびにその日のスナップショットを上書きして残しておく。
    ///
    /// 参考元は階層・分野で絞ったグラフを描くために内訳を辞書で持っていたが、
    /// 本アプリに絞り込みの軸は無く、単語と文法の2本だけあれば足りる。
    var masteredWordCount: Int = 0
    var masteredGrammarCount: Int = 0

    init(
        date: Date,
        studiedItemCount: Int = 0,
        correctCount: Int = 0,
        attemptCount: Int = 0,
        masteredWordCount: Int = 0,
        masteredGrammarCount: Int = 0
    ) {
        self.date = date
        self.studiedItemCount = studiedItemCount
        self.correctCount = correctCount
        self.attemptCount = attemptCount
        self.masteredWordCount = masteredWordCount
        self.masteredGrammarCount = masteredGrammarCount
    }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }

    var masteredTotal: Int { masteredWordCount + masteredGrammarCount }
}
