import SwiftUI

struct EditorView: View {
    @Environment(AppStore.self) var store
    @State private var text: String = ""
    @State private var isLoadingAI = false
    @State private var aiError: String?
    @State private var showAIPanel = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        if let scene = store.selectedScene {
            VStack(spacing: 0) {
                editorToolbar(scene: scene)
                Divider()
                textEditor
                Divider()
                statusBar(scene: scene)
            }
            .onAppear { text = scene.content }
            .onChange(of: store.selectedSceneID) { _, _ in
                if let s = store.selectedScene { text = s.content }
            }
            .sheet(isPresented: $showAIPanel) {
                AIPanelView(text: $text)
            }
        } else {
            emptyState
        }
    }

    private func editorToolbar(scene: Scene) -> some View {
        HStack {
            Text(scene.title)
                .font(.headline)
                .padding(.leading)
            Spacer()
            // Autosave indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(store.savedFlash ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: store.savedFlash)
            .padding(.trailing, 8)

            Button {
                store.isDistractionFreeMode = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Distraction-Free Mode")
            Button {
                showAIPanel = true
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("AI Writing Assistant")
            .padding(.trailing)
        }
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var textEditor: some View {
        TextEditor(text: $text)
            .font(.system(size: 16, weight: .regular, design: .serif))
            .lineSpacing(6)
            .padding(.horizontal, 60)
            .padding(.vertical, 24)
            .focused($editorFocused)
            .onChange(of: text) { _, newValue in
                store.updateSceneContent(newValue)
            }
    }

    private func statusBar(scene: Scene) -> some View {
        HStack {
            Text("\(scene.wordCount) words")
            Spacer()
            let progress = min(Double(store.todayWordCount) / Double(store.novel.dailyWordGoal), 1.0)
            Text("Today: \(store.todayWordCount) / \(store.novel.dailyWordGoal)")
                .foregroundStyle(progress >= 1.0 ? .green : .secondary)
            ProgressView(value: progress)
                .frame(width: 80)
                .tint(progress >= 1.0 ? .green : .accentColor)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a scene to start writing")
                .foregroundStyle(.secondary)
            Button("Add Chapter") { store.addChapter() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
