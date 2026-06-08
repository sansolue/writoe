import SwiftUI

@main
struct WritoeApp: App {
    @State private var store = AppStore()
    @State private var projects = ProjectManager()

    var body: some SwiftUI.Scene {
        WindowGroup {
            Group {
                if store.fileURL != nil {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environment(store)
            .environment(projects)
            .frame(minWidth: store.fileURL != nil ? 900 : 720,
                   minHeight: store.fileURL != nil ? 600 : 460)
            .onAppear { wireCallbacks() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Novel…") { newNovel() }
                    .keyboardShortcut("N", modifiers: .command)

                Button("Open Novel…") { openNovel() }
                    .keyboardShortcut("O", modifiers: .command)

                Divider()

                Button("Close Project") { store.closeProject() }
                    .keyboardShortcut("W", modifiers: [.command, .shift])
                    .disabled(store.fileURL == nil)

                Button("Export…") {
                    store.showExportSheet = true
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])
                .disabled(store.fileURL == nil)

                Divider()

                Menu("Open Recent") {
                    if projects.recentProjects.isEmpty {
                        Text("No Recent Projects").foregroundStyle(.secondary)
                    } else {
                        ForEach(projects.recentProjects) { record in
                            Button(record.title) { open(url: record.url) }
                        }
                        Divider()
                        Button("Clear Recents") {
                            projects.recentProjects.removeAll()
                        }
                    }
                }
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("New Chapter") { store.addChapter() }
                    .keyboardShortcut("N", modifiers: [.command, .shift])
                    .disabled(store.fileURL == nil)

                Button("New Scene") {
                    if let id = store.selectedChapterID { store.addScene(to: id) }
                }
                .keyboardShortcut("N", modifiers: [.command, .option])
                .disabled(store.selectedChapterID == nil)

                Divider()

                Button("Distraction-Free Mode") { store.isDistractionFreeMode.toggle() }
                    .keyboardShortcut("F", modifiers: [.command, .control])
                    .disabled(store.fileURL == nil)
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Writoe") { NSApp.orderFrontStandardAboutPanel() }
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(projects)
        }
    }

    // MARK: - Actions

    private func wireCallbacks() {
        store.onProjectSaved = { [weak projects] novel, url in
            projects?.updateRecord(for: novel, at: url)
        }
    }

    private func newNovel() {
        guard let url = projects.showNewPanel() else { return }
        store.loadProject(from: url)
        wireCallbacks()
    }

    private func openNovel() {
        guard let url = projects.showOpenPanel() else { return }
        open(url: url)
    }

    private func open(url: URL) {
        store.loadProject(from: url)
        projects.updateRecord(for: store.novel, at: url)
        wireCallbacks()
    }
}
