import Foundation

struct Novel: Codable {
    var id: UUID = UUID()
    var title: String = "Untitled Novel"
    var author: String = ""
    var synopsis: String = ""
    var genre: String = ""
    var chapters: [Chapter] = []
    var characters: [Character] = []
    var dailyWordGoal: Int = 1000
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var totalWordCount: Int {
        chapters.reduce(0) { $0 + $1.wordCount }
    }

    mutating func addChapter(titled title: String = "") {
        var chapter = Chapter(title: title)
        chapter.order = chapters.count
        chapter.addScene()
        chapters.append(chapter)
        modifiedAt = Date()
    }

    mutating func deleteChapter(id: UUID) {
        chapters.removeAll { $0.id == id }
        modifiedAt = Date()
    }

    mutating func moveChapters(from source: IndexSet, to destination: Int) {
        chapters.move(fromOffsets: source, toOffset: destination)
        for i in chapters.indices { chapters[i].order = i }
        modifiedAt = Date()
    }

    mutating func addCharacter(named name: String) {
        let character = Character(name: name)
        characters.append(character)
        modifiedAt = Date()
    }

    mutating func deleteCharacter(id: UUID) {
        characters.removeAll { $0.id == id }
        modifiedAt = Date()
    }

    // Returns the first scene matching the given ID, along with its chapter index and scene index
    func findScene(id: UUID) -> (chapterIndex: Int, sceneIndex: Int)? {
        for (ci, chapter) in chapters.enumerated() {
            for (si, scene) in chapter.scenes.enumerated() {
                if scene.id == id { return (ci, si) }
            }
        }
        return nil
    }
}
