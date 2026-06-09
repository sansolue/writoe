import Foundation
import NaturalLanguage

struct Scene: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String = ""
    var synopsis: String = ""
    var characterIDs: [UUID] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var wordCount: Int {
        guard !content.isEmpty else { return 0 }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = content
        var count = 0
        tokenizer.enumerateTokens(in: content.startIndex..<content.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        modifiedAt = Date()
    }
}
