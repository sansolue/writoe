import SwiftUI

struct FindResult: Identifiable {
    let id = UUID()
    let chapterID: UUID
    let chapterTitle: String
    let sceneID: UUID
    let sceneTitle: String
    let excerpt: String
    let matchCount: Int
}

struct GlobalFindView: View {
    @Environment(AppStore.self) var store
    @State private var query = ""
    @State private var caseSensitive = false
    @FocusState private var searchFocused: Bool

    var results: [FindResult] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        var found: [FindResult] = []
        for (ci, chapter) in store.novel.chapters.enumerated() {
            for scene in chapter.scenes {
                let haystack = caseSensitive ? scene.content : scene.content.lowercased()
                let needle   = caseSensitive ? q : q.lowercased()
                guard haystack.contains(needle) else { continue }

                // Count matches and grab first excerpt
                var count = 0
                var firstRange: Range<String.Index>? = nil
                var cursor = haystack.startIndex
                while let r = haystack.range(of: needle, range: cursor..<haystack.endIndex) {
                    if firstRange == nil { firstRange = r }
                    count += 1
                    cursor = r.upperBound
                }

                let excerpt = firstRange.map { makeExcerpt(scene.content, around: $0) } ?? ""
                let chapterLabel = chapter.title.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Chapter \(ci + 1)"
                    : "Chapter \(ci + 1): \(chapter.title)"

                found.append(FindResult(
                    chapterID: chapter.id,
                    chapterTitle: chapterLabel,
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    excerpt: excerpt,
                    matchCount: count
                ))
            }
        }
        return found
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            resultsList
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { searchFocused = true }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search in novel…", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { navigateToFirst() }
            if !query.isEmpty {
                Text(resultSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Toggle("Aa", isOn: $caseSensitive)
                .toggleStyle(.button)
                .help("Case sensitive")
            Divider().frame(height: 16)
            Button {
                store.showGlobalFind = false
            } label: {
                Image(systemName: "xmark").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            placeholder("Search across all chapters and scenes")
        } else if results.isEmpty {
            placeholder("No results for \"\(query)\"")
        } else {
            List(results) { result in
                FindResultRow(result: result, query: query, caseSensitive: caseSensitive) {
                    navigate(to: result)
                }
            }
            .listStyle(.plain)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var resultSummary: String {
        let total = results.reduce(0) { $0 + $1.matchCount }
        return total == 1 ? "1 match" : "\(total) matches"
    }

    private func navigate(to result: FindResult) {
        store.selectedChapterID = result.chapterID
        store.selectedSceneID   = result.sceneID
        store.activeView        = .editor
        store.showGlobalFind    = false
    }

    private func navigateToFirst() {
        if let first = results.first { navigate(to: first) }
    }

    private func makeExcerpt(_ content: String, around range: Range<String.Index>) -> String {
        let radius = 50
        let start = content.index(range.lowerBound, offsetBy: -min(radius, content.distance(from: content.startIndex, to: range.lowerBound)))
        let end   = content.index(range.upperBound,  offsetBy:  min(radius, content.distance(from: range.upperBound, to: content.endIndex)))
        var excerpt = String(content[start..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if start > content.startIndex { excerpt = "…" + excerpt }
        if end   < content.endIndex   { excerpt = excerpt + "…" }
        return excerpt
    }
}

// MARK: - Result row

private struct FindResultRow: View {
    let result: FindResult
    let query: String
    let caseSensitive: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(result.chapterTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("›")
                        .foregroundStyle(.tertiary)
                    Text(result.sceneTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.matchCount == 1 ? "1 match" : "\(result.matchCount) matches")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                highlightedExcerpt
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovered ? Color.accentColor.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var highlightedExcerpt: some View {
        let text = result.excerpt
        let q = caseSensitive ? query : query.lowercased()
        let hay = caseSensitive ? text : text.lowercased()

        var parts: [(String, Bool)] = [] // (segment, isMatch)
        var cursor = text.startIndex
        var hayCursor = hay.startIndex

        while let r = hay.range(of: q, range: hayCursor..<hay.endIndex) {
            let before = String(text[cursor..<r.lowerBound])
            let match  = String(text[r.lowerBound..<r.upperBound])
            if !before.isEmpty { parts.append((before, false)) }
            parts.append((match, true))
            cursor    = r.upperBound
            hayCursor = r.upperBound
        }
        if cursor < text.endIndex { parts.append((String(text[cursor...]), false)) }

        return parts.reduce(Text("")) { acc, part in
            let seg = part.1
                ? Text(part.0).bold().foregroundStyle(Color.accentColor)
                : Text(part.0).foregroundStyle(Color.primary)
            return acc + seg
        }
        .font(.subheadline)
        .lineLimit(2)
    }
}
