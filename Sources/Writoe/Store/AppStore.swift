import Foundation
import Observation

@Observable
final class AppStore {
    var novel: Novel = Novel()
    var fileURL: URL?
    var selectedChapterID: UUID?
    var selectedSceneID: UUID?
    var selectedCharacterID: UUID?
    var isDistractionFreeMode: Bool = false
    var showCharacters: Bool = false
    var todayWordCount: Int = 0
    var aiAPIKey: String = ""

    var onProjectSaved: ((Novel, URL) -> Void)?
    var savedFlash: Bool = false
    var showExportSheet: Bool = false

    init() {
        loadTodayCount()
        aiAPIKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
        if let last = Self.lastUsedURL, FileManager.default.fileExists(atPath: last.path) {
            loadProject(from: last)
        }
    }

    func saveAPIKey() {
        UserDefaults.standard.set(aiAPIKey, forKey: "anthropicAPIKey")
    }

    // MARK: - Project Lifecycle

    func loadProject(from url: URL) {
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
        showCharacters = false
        isDistractionFreeMode = false
        Self.lastUsedURL = url
        save()
    }

    func closeProject() {
        save()
        fileURL = nil
        novel = Novel()
        selectedChapterID = nil
        selectedSceneID = nil
        selectedCharacterID = nil
        showCharacters = false
    }

    // MARK: - Scene Content

    var selectedScene: Scene? {
        guard let sceneID = selectedSceneID,
              let location = novel.findScene(id: sceneID) else { return nil }
        return novel.chapters[location.chapterIndex].scenes[location.sceneIndex]
    }

    func updateSceneContent(_ content: String) {
        guard let sceneID = selectedSceneID,
              let location = novel.findScene(id: sceneID) else { return }
        let old = novel.chapters[location.chapterIndex].scenes[location.sceneIndex].content
        novel.chapters[location.chapterIndex].scenes[location.sceneIndex].updateContent(content)
        let delta = content.split(separator: " ").filter { !$0.isEmpty }.count
                  - old.split(separator: " ").filter { !$0.isEmpty }.count
        if delta > 0 { todayWordCount += delta }
        save()
    }

    func updateSceneTitle(_ title: String) {
        guard let sceneID = selectedSceneID,
              let location = novel.findScene(id: sceneID) else { return }
        novel.chapters[location.chapterIndex].scenes[location.sceneIndex].title = title
        save()
    }

    func updateSceneSynopsis(_ synopsis: String) {
        guard let sceneID = selectedSceneID,
              let location = novel.findScene(id: sceneID) else { return }
        novel.chapters[location.chapterIndex].scenes[location.sceneIndex].synopsis = synopsis
        save()
    }

    // MARK: - Chapter/Scene Mutations

    func addChapter() {
        novel.addChapter()
        if let newChapter = novel.chapters.last {
            selectedChapterID = newChapter.id
            selectedSceneID = newChapter.scenes.first?.id
        }
        save()
    }

    func deleteChapter(id: UUID) {
        novel.deleteChapter(id: id)
        if selectedChapterID == id {
            selectedChapterID = novel.chapters.first?.id
            selectedSceneID = novel.chapters.first?.scenes.first?.id
        }
        save()
    }

    func addScene(to chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].addScene()
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
        guard let location = novel.findScene(id: id) else { return }
        novel.chapters[location.chapterIndex].scenes[location.sceneIndex].title = title
        save()
    }

    func moveChapters(from source: IndexSet, to destination: Int) {
        novel.moveChapters(from: source, to: destination)
        save()
    }

    func moveScenes(from source: IndexSet, to destination: Int, in chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].moveScenes(from: source, to: destination)
        save()
    }

    func deleteScene(id: UUID, from chapterID: UUID) {
        guard let idx = novel.chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        novel.chapters[idx].deleteScene(id: id)
        if selectedSceneID == id {
            selectedSceneID = novel.chapters[idx].scenes.first?.id
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
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(novel)
            try data.write(to: url, options: .atomic)
            Self.lastUsedURL = url
            onProjectSaved?(novel, url)
            Task { @MainActor in
                savedFlash = true
                try? await Task.sleep(for: .seconds(2))
                savedFlash = false
            }
        } catch {
            print("Save failed: \(error)")
        }
    }

    private static var lastUsedURL: URL? {
        get {
            UserDefaults.standard.url(forKey: "lastProjectURL")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastProjectURL")
        }
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
