import Foundation

struct Chapter: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var synopsis: String = ""
    var scenes: [Scene] = []
    var order: Int = 0
    var createdAt: Date = Date()

    var wordCount: Int {
        scenes.reduce(0) { $0 + $1.wordCount }
    }

    mutating func addScene(titled title: String = "New Scene") {
        let scene = Scene(title: title)
        scenes.append(scene)
    }

    mutating func deleteScene(id: UUID) {
        scenes.removeAll { $0.id == id }
    }

    mutating func moveScenes(from source: IndexSet, to destination: Int) {
        scenes.move(fromOffsets: source, toOffset: destination)
    }
}
