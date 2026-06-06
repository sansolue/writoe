import Foundation

enum CharacterRole: String, Codable, CaseIterable {
    case protagonist = "Protagonist"
    case antagonist = "Antagonist"
    case supporting = "Supporting"
    case minor = "Minor"

    var color: String {
        switch self {
        case .protagonist: return "blue"
        case .antagonist: return "red"
        case .supporting: return "green"
        case .minor: return "gray"
        }
    }
}

struct Character: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var role: CharacterRole = .supporting
    var description: String = ""
    var backstory: String = ""
    var traits: [String] = []
    var notes: String = ""
    var createdAt: Date = Date()
}
