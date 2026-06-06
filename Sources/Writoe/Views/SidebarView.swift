import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selectedSceneID) {
            novelHeader
            manuscriptSection
            charactersSection
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { store.addChapter() }) {
                    Label("Add Chapter", systemImage: "plus")
                }
            }
        }
    }

    private var novelHeader: some View {
        Section {
            Label(store.novel.title, systemImage: "book.closed")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private var manuscriptSection: some View {
        Section("Manuscript") {
            ForEach(Array(store.novel.chapters.enumerated()), id: \.element.id) { index, chapter in
                ChapterRowView(chapter: chapter, number: index + 1)
            }
            .onMove { from, to in
                store.moveChapters(from: from, to: to)
            }
        }
    }

    private var charactersSection: some View {
        Section("Characters") {
            ForEach(store.novel.characters) { character in
                Label {
                    Text(character.name)
                } icon: {
                    Image(systemName: "person.fill")
                        .foregroundStyle(roleColor(character.role))
                }
                .tag(character.id)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        store.deleteCharacter(id: character.id)
                    }
                }
                .onTapGesture {
                    store.selectedCharacterID = character.id
                    store.showCharacters = true
                }
            }
            Button {
                store.addCharacter(named: "New Character")
                store.showCharacters = true
            } label: {
                Label("Add Character", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func roleColor(_ role: CharacterRole) -> Color {
        switch role {
        case .protagonist: return .blue
        case .antagonist: return .red
        case .supporting: return .green
        case .minor: return .gray
        }
    }
}

// MARK: - Chapter Row

struct ChapterRowView: View {
    @Environment(AppStore.self) var store
    var chapter: Chapter
    var number: Int
    @State private var isExpanded = true
    @State private var lastTapTime: Date = .distantPast
    @State private var pendingRename: Task<Void, Never>?

    var displayTitle: String {
        chapter.title.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Chapter \(number)"
            : "Chapter \(number): \(chapter.title)"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(chapter.scenes) { scene in
                SceneRowView(scene: scene, chapterID: chapter.id)
            }
            .onMove { from, to in
                store.moveScenes(from: from, to: to, in: chapter.id)
            }
            Button {
                store.addScene(to: chapter.id)
            } label: {
                Label("Add Scene", systemImage: "plus")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        } label: {
            Label {
                // Button inside DisclosureGroup label reliably receives clicks
                // unlike onTapGesture or simultaneousGesture in this context
                Button(action: handleTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                        Text("\(chapter.wordCount) words")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } icon: {
                Image(systemName: "bookmark")
            }
        }
        .contextMenu {
            Button("Rename Chapter") { beginRename() }
            Divider()
            Button("Delete Chapter", role: .destructive) {
                store.deleteChapter(id: chapter.id)
            }
        }
    }

    private func handleTap() {
        let now = Date()
        let gap = now.timeIntervalSince(lastTapTime)
        let wasActive = store.selectedChapterID == chapter.id
        lastTapTime = now
        store.selectedChapterID = chapter.id
        pendingRename?.cancel()
        if wasActive && gap > 0.3 {
            pendingRename = Task {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run { beginRename() }
            }
        }
    }

    private func beginRename() {
        let alert = NSAlert()
        alert.messageText = "Rename Chapter"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        tf.stringValue = chapter.title
        tf.placeholderString = "e.g. The Beginning"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                let trimmed = tf.stringValue.trimmingCharacters(in: .whitespaces)
                store.renameChapter(id: chapter.id, title: trimmed)
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = tf.stringValue.trimmingCharacters(in: .whitespaces)
            store.renameChapter(id: chapter.id, title: trimmed)
        }
    }
}

// MARK: - Scene Row

struct SceneRowView: View {
    @Environment(AppStore.self) var store
    var scene: Scene
    var chapterID: UUID
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var lastTapTime: Date = .distantPast
    @State private var pendingRename: Task<Void, Never>?

    var isSelected: Bool { store.selectedSceneID == scene.id }

    var body: some View {
        Group {
            if isRenaming {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    TextField("Scene title", text: $renameText)
                        .textFieldStyle(.plain)
                        .onSubmit { commitRename() }
                        .onExitCommand { isRenaming = false }
                        .onAppear { renameText = scene.title }
                }
            } else {
                Label(scene.title, systemImage: "doc.text")
                    .tag(scene.id)
                    .onTapGesture { handleTap() }
            }
        }
        .contextMenu {
            Button("Rename Scene") { beginRename() }
            Divider()
            Button("Delete Scene", role: .destructive) {
                store.deleteScene(id: scene.id, from: chapterID)
            }
        }
    }

    private func handleTap() {
        let now = Date()
        let gap = now.timeIntervalSince(lastTapTime)
        lastTapTime = now
        pendingRename?.cancel()

        if isSelected && gap > 0.3 {
            // Slow second click on already-selected scene → rename
            pendingRename = Task {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run { beginRename() }
            }
        } else {
            // First click or fast double-click → just select
            store.selectedChapterID = chapterID
            store.selectedSceneID = scene.id
            store.showCharacters = false
        }
    }

    private func beginRename() {
        renameText = scene.title
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { store.renameScene(id: scene.id, title: trimmed) }
        isRenaming = false
    }
}
