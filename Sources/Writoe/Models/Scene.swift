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
    private(set) var wordCount: Int = 0

    init(title: String) {
        self.title = title
    }

    // wordCount is derived from content; excluded from JSON so it is always
    // recomputed on load rather than persisting a potentially stale value.
    enum CodingKeys: CodingKey {
        case id, title, content, synopsis, characterIDs, createdAt, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self,   forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        content      = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        synopsis     = try c.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        characterIDs = try c.decodeIfPresent([UUID].self, forKey: .characterIDs) ?? []
        createdAt    = try c.decodeIfPresent(Date.self,   forKey: .createdAt) ?? Date()
        modifiedAt   = try c.decodeIfPresent(Date.self,   forKey: .modifiedAt) ?? Date()
        wordCount    = Self.countWords(in: content)
    }

    mutating func updateContent(_ newContent: String) {
        content    = newContent
        modifiedAt = Date()
        wordCount  = Self.countWords(in: newContent)
    }

    private static func countWords(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }
}
