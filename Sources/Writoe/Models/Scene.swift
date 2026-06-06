import Foundation

struct Scene: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String = ""
    var synopsis: String = ""
    var characterIDs: [UUID] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var wordCount: Int {
        content.split(separator: " ").filter { !$0.isEmpty }.count
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        modifiedAt = Date()
    }
}
