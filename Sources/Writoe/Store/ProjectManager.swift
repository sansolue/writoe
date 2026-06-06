import Foundation
import AppKit
import Observation

struct ProjectRecord: Codable, Identifiable, Equatable {
    var id: URL { url }
    var url: URL
    var title: String
    var wordCount: Int
    var modifiedAt: Date
}

@Observable
final class ProjectManager {
    var recentProjects: [ProjectRecord] = []

    private let defaultsKey = "recentProjects"

    init() {
        loadRecents()
    }

    // MARK: - File Panels

    @MainActor
    func showNewPanel() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create New Novel"
        panel.prompt = "Create"
        panel.nameFieldStringValue = "My Novel"
        panel.allowedContentTypes = [.writoe]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    @MainActor
    func showOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Novel"
        panel.prompt = "Open"
        panel.allowedContentTypes = [.writoe]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    // MARK: - Recents Management

    func updateRecord(for novel: Novel, at url: URL) {
        let record = ProjectRecord(
            url: url,
            title: novel.title,
            wordCount: novel.totalWordCount,
            modifiedAt: novel.modifiedAt
        )
        recentProjects.removeAll { $0.url == url }
        recentProjects.insert(record, at: 0)
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        saveRecents()
    }

    func remove(at offsets: IndexSet) {
        recentProjects.remove(atOffsets: offsets)
        saveRecents()
    }

    // MARK: - Persistence

    private func saveRecents() {
        guard let data = try? JSONEncoder().encode(recentProjects) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let records = try? JSONDecoder().decode([ProjectRecord].self, from: data) else { return }
        recentProjects = records.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }
}

import UniformTypeIdentifiers
extension UTType {
    static let writoe = UTType(exportedAs: "com.writoe.document", conformingTo: .json)
}
