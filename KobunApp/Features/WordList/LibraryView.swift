import SwiftUI
import SwiftData

/// 単語帳タブ。上部のセグメントで単語と文法を切り替える。
///
/// 文法を独立タブにしなかったのは、どちらも「覚える対象の一覧を引く」という
/// 同じ役割の画面だから。タブを5つに増やすより切り替えのほうが迷いが少ない。
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: Bindable(viewModel).segment) {
                    ForEach(LibrarySegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                StatusFilterBar(selection: Bindable(viewModel).statusFilter)

                if viewModel.visibleCount == 0 {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("単語帳")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Bindable(viewModel).searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: viewModel.segment == .word ? "見出し語・読み・意味で検索" : "文法項目・解説で検索"
            )
        }
        .onAppear { viewModel.configure(context: context) }
    }

    @ViewBuilder
    private var list: some View {
        List {
            switch viewModel.segment {
            case .word:
                Section {
                    ForEach(viewModel.filteredWords) { word in
                        NavigationLink {
                            WordDetailView(word: word, viewModel: viewModel)
                        } label: {
                            WordRow(word: word, status: viewModel.wordStatus[word.wordId] ?? .notStudied)
                        }
                    }
                } header: {
                    Text("\(viewModel.filteredWords.count) 語")
                }

            case .grammar:
                ForEach(viewModel.filteredGrammarSections, id: \.category) { section in
                    Section {
                        ForEach(section.items) { item in
                            NavigationLink {
                                GrammarDetailView(grammar: item, viewModel: viewModel)
                            } label: {
                                GrammarRow(
                                    grammar: item,
                                    status: viewModel.grammarStatus[item.grammarId] ?? .notStudied
                                )
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.category.displayName)
                            Text(section.category.summary)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            viewModel.isFiltering ? "該当する項目がありません" : "データがありません",
            systemImage: viewModel.isFiltering ? "magnifyingglass" : "book.closed",
            description: Text(
                viewModel.isFiltering
                    ? "検索語や絞り込みを変えてお試しください。"
                    : "アプリを再起動すると学習データを読み直します。"
            )
        )
    }
}

/// 習熟度での絞り込み。件数を出さないのは、押すたびに全件を数え直すことになるため。
private struct StatusFilterBar: View {
    @Binding var selection: LearningStatus?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "すべて", status: nil)
                ForEach(LearningStatus.allCases) { status in
                    chip(title: status.displayName, status: status)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(title: String, status: LearningStatus?) -> some View {
        let isSelected = selection == status
        return Button {
            selection = status
        } label: {
            HStack(spacing: 4) {
                if let status {
                    Image(systemName: status.symbolName)
                        .font(.caption2)
                }
                Text(title).font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? (status?.tint ?? Color.accentColor).opacity(0.2) : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? (status?.tint ?? Color.accentColor) : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct WordRow: View {
    let word: WordMaster
    let status: LearningStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.tint)
                .font(.subheadline)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(word.word)
                        .font(.body.weight(.medium))
                    if word.needsReadingAnnotation {
                        Text(word.reading)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(word.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GrammarRow: View {
    let grammar: GrammarMaster
    let status: LearningStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.tint)
                .font(.subheadline)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(grammar.title)
                    .font(.body.weight(.medium))
                Text(grammar.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
