import Foundation
import Observation

enum MainView {
    case editor, corkboard, characters
}

@Observable
final class AppStore {
    var novel: Novel = Novel()
    var fileURL: URL?
    var selectedChapterID: UUID?
    var selectedSceneID: UUID?
    var selectedCharacterID: UUID?
    var isDistractionFreeMode: Bool = false
    var activeView: MainView = .editor
    var todayWordCount: Int = 0
    var aiAPIKey: String = ""

    var onProjectSaved: ((Novel, URL) -> Void)?
    var savedFlash: Bool = false
    var showExportSheet: Bool = false
    var showGlobalFind: Bool = false
    var writingTheme: WritingTheme = .system

    private var saveDebounceTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?

    // One-entry cache so findScene is O(1) on the hot typing path.
    // Cleared on any structural mutation to chapters or scenes.
    private var cachedSceneLocation: (id: UUID, ci: Int, si: Int)?

    func saveTheme() {
        UserDefaults.standard.set(writingTheme.rawValue, forKey: "writingTheme")
    }

    init() {
        loadTodayCount()
        aiAPIKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
        let themeRaw = UserDefaults.standard.string(forKey: "writingTheme") ?? "system"
        writingTheme = WritingTheme(rawValue: themeRaw) ?? .system
        if let last = Self.lastUsedURL, FileManager.default.fileExists(atPath: last.path) {
            loadProject(from: last)
        }
    }

    func saveAPIKey() {
        UserDefaults.standard.set(aiAPIKey, forKey: "anthropicAPIKey")
    }

    // MARK: - Project Lifecycle

    func loadProject(from url: URL) {
        let fileAlreadyExists = FileManager.default.fileExists(atPath: url.path)
        invalidateSceneCache()
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(Novel.self, from: data) {
            novel = saved
        } else {
            novel = Novel()
            novel.title = url.deletingPathExtension().lastPathComponent
            novel.addChapter()
        }
        fileURL = url
        selectedChapterID = novel.chapters.first?.id
        selectedSceneID = novel.chapters.first?.scenes.first?.id
        selectedCharacterID = nil
        activeView = .editor
        isDistractionFreeMode = false
        Self.lastUsedURL = url
        // Only create a new file on disk; never auto-overwrite an existing file
        // (e.g. one that failed to decode) — the user's data may still be recoverable.
        if !fileAlreadyExists { save() }
    }

    func closeProject() {
        saveDebounceTask?.cancel()
        invalidateSceneCache()
        save()
        fileURL = nil
        novel = Novel()
        selectedChapterID = nil
        selectedSceneID = nil
        selectedCharacterID = nil
        activeView = .editor
    }

    // MARK: - Scene Content

    var selectedScene: Scene? {
        guard let sceneID = selectedSceneID,
              let loc = cachedFindScene(id: sceneID) else { return nil }
        return novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex]
    }

    func updateSceneContent(_ content: String) {
        guard let sceneID = selectedSceneID,
              let loc = cachedFindScene(id: sceneID) else { return }
        let oldCount = novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].wordCount
        novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].updateContent(content)
        let delta = novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].wordCount - oldCount
        todayWordCount = max(0, todayWordCount + delta)
        scheduleSave()
    }

    func updateSceneTitle(_ title: String) {
        guard let sceneID = selectedSceneID,
              let loc = cachedFindScene(id: sceneID) else { return }
        novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].title = title
        save()
    }

    func updateSceneSynopsis(_ synopsis: String) {
        guard let sceneID = selectedSceneID,
              let loc = cachedFindScene(id: sceneID) else { return }
        novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].synopsis = synopsis
        scheduleSave()
    }

    func updateSceneSynopsis(_ synopsis: String, for sceneID: UUID) {
        guard let loc = cachedFindScene(id: sceneID) else { return }
        novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].synopsis = synopsis
        scheduleSave()
    }

    // MARK: - Chapter/Scene Mutations

    func addChapter() {
        novel.addChapter()
        invalidateSceneCache()
        if let newChapter = novel.chapters.last {
            selectedChapterID = newChapter.id
            selectedSceneID = newChapter.scenes.first?.id
        }
        save()
    }

    func deleteChapter(id: UUID) {
        novel.deleteChapter(id: id)
        invalidateSceneCache()
        if selectedChapterID == id {
            selectedChapterID = novel.chapters.first?.id
            selectedSceneID = novel.chapters.first?.scenes.first?.id
        }
        save()
    }

    func addScene(to chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].addScene()
        invalidateSceneCache()
        selectedChapterID = chapterID
        selectedSceneID = novel.chapters[idx].scenes.last?.id
        save()
    }

    func renameChapter(id: UUID, title: String) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == id }) else { return }
        novel.chapters[idx].title = title
        save()
    }

    func renameScene(id: UUID, title: String) {
        guard let loc = cachedFindScene(id: id) else { return }
        novel.chapters[loc.chapterIndex].scenes[loc.sceneIndex].title = title
        save()
    }

    func moveChapters(from source: IndexSet, to destination: Int) {
        novel.moveChapters(from: source, to: destination)
        invalidateSceneCache()
        save()
    }

    func moveScenes(from source: IndexSet, to destination: Int, in chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].moveScenes(from: source, to: destination)
        invalidateSceneCache()
        save()
    }

    func deleteScene(id: UUID, from chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].deleteScene(id: id)
        invalidateSceneCache()
        if selectedSceneID == id {
            if let next = novel.chapters[idx].scenes.first {
                // Chapter still has scenes — stay in the same chapter
                selectedSceneID = next.id
            } else if let fallback = novel.chapters.first(where: { !$0.scenes.isEmpty }) {
                // This chapter is empty — move to another chapter that has scenes
                selectedChapterID = fallback.id
                selectedSceneID   = fallback.scenes.first?.id
            } else {
                // All chapters are empty — stay on this chapter so ⌘⌥N still works
                selectedChapterID = novel.chapters[idx].id
                selectedSceneID   = nil
            }
        }
        save()
    }

    // MARK: - Character Mutations

    func addCharacter(named name: String) {
        novel.addCharacter(named: name)
        selectedCharacterID = novel.characters.last?.id
        save()
    }

    func deleteCharacter(id: UUID) {
        novel.deleteCharacter(id: id)
        if selectedCharacterID == id {
            selectedCharacterID = novel.characters.first?.id
        }
        save()
    }

    func updateCharacter(_ updated: Character) {
        guard let idx = novel.characters.firstIndex(where: { $0.id == updated.id }) else { return }
        novel.characters[idx] = updated
        scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(novel)
            try data.write(to: url, options: .atomic)
            Self.lastUsedURL = url
            onProjectSaved?(novel, url)
            flashTask?.cancel()
            flashTask = Task { @MainActor [weak self] in
                self?.savedFlash = true
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.savedFlash = false
            }
        } catch {
            print("Save failed: \(error)")
        }
    }

    // MARK: - Scene cache

    private func cachedFindScene(id: UUID) -> (chapterIndex: Int, sceneIndex: Int)? {
        if let c = cachedSceneLocation, c.id == id {
            return (c.ci, c.si)
        }
        guard let loc = novel.findScene(id: id) else { return nil }
        cachedSceneLocation = (id, loc.chapterIndex, loc.sceneIndex)
        return loc
    }

    private func invalidateSceneCache() {
        cachedSceneLocation = nil
    }

    // MARK: - UserDefaults

    private static var lastUsedURL: URL? {
        get { UserDefaults.standard.url(forKey: "lastProjectURL") }
        set { UserDefaults.standard.set(newValue, forKey: "lastProjectURL") }
    }

    private func loadTodayCount() {
        let key = "wordCount_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        todayWordCount = UserDefaults.standard.integer(forKey: key)
    }

    func saveTodayCount() {
        let key = "wordCount_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        UserDefaults.standard.set(todayWordCount, forKey: key)
    }
}
