import SwiftUI
import UniformTypeIdentifiers

// MARK: - Corkboard

struct CorkboardView: View {
    @Environment(AppStore.self) var store
    @State private var draggingID: UUID?
    @State private var highlightedID: UUID?

    private let cardW: CGFloat = 200
    private let cardH: CGFloat = 230
    private let gap:   CGFloat = 20
    private let cols = [GridItem(.adaptive(minimum: 190, maximum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                ForEach(Array(store.novel.chapters.enumerated()), id: \.element.id) { ci, chapter in
                    chapterSection(chapter: chapter, index: ci)
                }
            }
            .padding(28)
        }
        .background(corkBackground)
    }

    // MARK: - Cork background

    private var corkBackground: some View {
        ZStack {
            Color(red: 0.72, green: 0.60, blue: 0.44)
            // Subtle grain overlay
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.black.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Chapter section

    @ViewBuilder
    private func chapterSection(chapter: Chapter, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Chapter label — looks like a pinned strip of tape
            Text(chapterLabel(chapter, index: index))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(pinColor(index).opacity(0.85))
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                )

            LazyVGrid(columns: cols, spacing: gap) {
                ForEach(chapter.scenes) { scene in
                    SceneCard(
                        scene: scene,
                        chapter: chapter,
                        chapterIndex: index,
                        draggingID: $draggingID,
                        highlightedID: $highlightedID
                    )
                    .frame(height: cardH)
                    .id(scene.id)
                }

                // Add scene button
                AddSceneCard { store.addScene(to: chapter.id) }
                    .frame(height: cardH)
            }
        }
    }

    // MARK: - Helpers

    private func chapterLabel(_ chapter: Chapter, index: Int) -> String {
        let title = chapter.title.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "Chapter \(index + 1)" : "Chapter \(index + 1): \(title)"
    }

    private func pinColor(_ index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .brown]
        return colors[index % colors.count]
    }
}

// MARK: - Scene card

private struct SceneCard: View {
    @Environment(AppStore.self) var store
    let scene: Scene
    let chapter: Chapter
    let chapterIndex: Int
    @Binding var draggingID: UUID?
    @Binding var highlightedID: UUID?

    @State private var titleDraft: String
    @State private var synopsisDraft: String
    @FocusState private var synopsisFocused: Bool

    init(scene: Scene, chapter: Chapter, chapterIndex: Int,
         draggingID: Binding<UUID?>, highlightedID: Binding<UUID?>) {
        self.scene = scene
        self.chapter = chapter
        self.chapterIndex = chapterIndex
        _draggingID = draggingID
        _highlightedID = highlightedID
        _titleDraft    = State(initialValue: scene.title)
        _synopsisDraft = State(initialValue: scene.synopsis)
    }

    private var isBeingDragged: Bool { draggingID == scene.id }
    private var isDropTarget:   Bool { highlightedID == scene.id }

    var body: some View {
        ZStack(alignment: .top) {
            // Card body
            RoundedRectangle(cornerRadius: 3)
                .fill(cardColor)
                .shadow(
                    color: .black.opacity(isBeingDragged ? 0.4 : 0.18),
                    radius: isBeingDragged ? 12 : 5,
                    x: 0, y: isBeingDragged ? 8 : 2
                )

            VStack(alignment: .leading, spacing: 0) {
                // Title
                TextField("Scene title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                    .onSubmit { commitTitle() }
                    .onChange(of: titleDraft) { _, _ in commitTitle() }

                Divider().padding(.horizontal, 12)

                // Synopsis
                TextEditor(text: $synopsisDraft)
                    .font(.system(size: 11))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .focused($synopsisFocused)
                    .onChange(of: synopsisDraft) { _, new in
                        store.updateSceneSynopsis(new, for: scene.id)
                    }

                Divider().padding(.horizontal, 12)

                // Footer
                HStack(spacing: 6) {
                    Text("\(scene.wordCount) words")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: openInEditor) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in editor")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Pin
            pinView
                .offset(y: -8)
        }
        // Force light appearance so text is always dark on the white card,
        // regardless of the system or writing theme.
        .colorScheme(.light)
        .opacity(isBeingDragged ? 0.45 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2.5)
        )
        .scaleEffect(isBeingDragged ? 0.97 : 1)
        .animation(.easeInOut(duration: 0.15), value: isBeingDragged)
        // Keep local drafts in sync with external store mutations (e.g. sidebar rename).
        // onAppear is intentionally absent — @State is seeded from scene in init() so
        // first appearance is already correct, and LazyVGrid card recreation re-runs init.
        // The equality guard prevents a feedback loop: when the user types, the draft
        // writes to the store, the store updates scene, and this fires — but by then
        // the draft already equals the new scene value, so no re-assignment happens.
        .onChange(of: scene.title) { _, newTitle in
            if titleDraft != newTitle { titleDraft = newTitle }
        }
        .onChange(of: scene.synopsis) { _, newSynopsis in
            if synopsisDraft != newSynopsis { synopsisDraft = newSynopsis }
        }
        // Drag source
        .onDrag {
            draggingID = scene.id
            return NSItemProvider(object: scene.id.uuidString as NSString)
        }
        // Drop target
        .onDrop(
            of: [UTType.plainText],
            delegate: CardDropDelegate(
                targetID: scene.id,
                chapterID: chapter.id,
                draggingID: $draggingID,
                highlightedID: $highlightedID,
                store: store
            )
        )
    }

    private var cardColor: Color {
        // Slight warm tint varies per chapter to break visual monotony
        let tints: [Color] = [
            .white,
            Color(red: 1, green: 0.99, blue: 0.94), // warm
            Color(red: 0.97, green: 0.99, blue: 1.0), // cool
            Color(red: 0.98, green: 1.0, blue: 0.97), // green tint
        ]
        return tints[chapterIndex % tints.count]
    }

    private var pinView: some View {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .brown]
        let color = colors[chapterIndex % colors.count]
        return ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: 16, height: 16)
            Circle().fill(color).frame(width: 9, height: 9)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
    }

    private func commitTitle() {
        let t = titleDraft.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { store.renameScene(id: scene.id, title: t) }
    }

    private func openInEditor() {
        store.selectedChapterID = chapter.id
        store.selectedSceneID   = scene.id
        store.activeView        = .editor
    }
}

// MARK: - Add Scene card

private struct AddSceneCard: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    Color.white.opacity(hovered ? 0.7 : 0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Add Scene")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                )
                .scaleEffect(hovered ? 1.02 : 1)
                .animation(.easeInOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Drop delegate

private struct CardDropDelegate: DropDelegate {
    let targetID:   UUID
    let chapterID:  UUID
    @Binding var draggingID:   UUID?
    @Binding var highlightedID: UUID?
    let store: AppStore

    func dropEntered(info: DropInfo)  { highlightedID = targetID }
    func dropExited(info: DropInfo)   { if highlightedID == targetID { highlightedID = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func validateDrop(info: DropInfo) -> Bool { draggingID != nil && draggingID != targetID }

    func performDrop(info: DropInfo) -> Bool {
        guard let fromID = draggingID,
              fromID != targetID,
              let chapter = store.novel.chapters.first(where: { $0.id == chapterID }),
              let fromIdx = chapter.scenes.firstIndex(where: { $0.id == fromID }),
              let toIdx   = chapter.scenes.firstIndex(where: { $0.id == targetID })
        else { return false }

        let dest = toIdx >= fromIdx ? toIdx + 1 : toIdx
        store.moveScenes(from: IndexSet([fromIdx]), to: dest, in: chapterID)
        draggingID    = nil
        highlightedID = nil
        return true
    }
}
