import Observation

enum AppTab: Hashable {
    case home, wordList, quiz, listening
}

/// クイズの出題ジャンル。参考元は単語だけだったが、本アプリは文法問題も出す。
enum QuizGenre: String, CaseIterable, Identifiable {
    case word
    case grammar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word: return "単語クイズ"
        case .grammar: return "文法クイズ"
        }
    }

    var symbolName: String {
        switch self {
        case .word: return "character.book.closed"
        case .grammar: return "text.badge.checkmark"
        }
    }

    var domain: StudyDomain {
        switch self {
        case .word: return .word
        case .grammar: return .grammar
        }
    }
}

/// クイズの出題対象。
enum QuizScope {
    /// 復習期限が来た項目を優先しつつ、足りなければ未学習で埋める（通常の学習）
    case mixed
    /// 復習期限が来た項目だけを出題する。ホームの「復習がN件あります」から入るときに使う。
    case reviewOnly
    /// 特定の文法項目に紐づく問題だけを出す。文法詳細の「この項目の問題を解く」から入る。
    case grammarItem(grammarId: String, title: String)

    var title: String {
        switch self {
        case .mixed: return "4択クイズ"
        case .reviewOnly: return "復習クイズ"
        case .grammarItem(_, let title): return title
        }
    }
}

/// クイズ画面を開くときの指定。ジャンルと対象をひとまとめにして渡す。
struct QuizRequest {
    var genre: QuizGenre
    var scope: QuizScope

    static let word = QuizRequest(genre: .word, scope: .mixed)
    static let grammar = QuizRequest(genre: .grammar, scope: .mixed)
}

/// ホーム画面や文法詳細のボタンから、TabViewの選択タブをコード側から切り替えるための共有ルーター。
@Observable
@MainActor
final class TabRouter {
    var selectedTab: AppTab = .home

    /// 次にクイズ画面が開かれたときに、この条件で自動的に開始する。
    /// ホームの復習ボタンが「復習する」と言いながら通常出題を始めてしまうのを避けるため、
    /// 遷移とあわせて出題対象を渡している。
    var pendingQuizRequest: QuizRequest?

    func startQuiz(_ request: QuizRequest) {
        pendingQuizRequest = request
        selectedTab = .quiz
    }

    /// クイズ画面が受け取ったら消費する（戻ってくるたびに再開始しないように）
    func consumePendingQuizRequest() -> QuizRequest? {
        defer { pendingQuizRequest = nil }
        return pendingQuizRequest
    }
}
