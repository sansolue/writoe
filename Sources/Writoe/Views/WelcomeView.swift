import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) var store
    @Environment(ProjectManager.self) var projects

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
            Divider()
            rightPanel
        }
        .frame(width: 720, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Left: Branding + Actions

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.accentColor)
                Text("Writoe")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                Text("Your novel writing companion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)

            VStack(spacing: 10) {
                Button(action: newNovel) {
                    Label("New Novel", systemImage: "plus.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: openNovel) {
                    Label("Open Novel…", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            Text("Version 1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(36)
        .frame(width: 260)
    }

    // MARK: - Right: Recent Projects

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Projects")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

            if projects.recentProjects.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No recent projects")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(projects.recentProjects) { record in
                            RecentProjectRow(record: record) {
                                open(record: record)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func newNovel() {
        guard let url = projects.showNewPanel() else { return }
        store.loadProject(from: url)
        projects.updateRecord(for: store.novel, at: url)
        store.onProjectSaved = { [weak projects] novel, url in
            projects?.updateRecord(for: novel, at: url)
        }
    }

    private func openNovel() {
        guard let url = projects.showOpenPanel() else { return }
        open(url: url)
    }

    private func open(record: ProjectRecord) {
        open(url: record.url)
    }

    private func open(url: URL) {
        store.loadProject(from: url)
        projects.updateRecord(for: store.novel, at: url)
        store.onProjectSaved = { [weak projects] novel, url in
            projects?.updateRecord(for: novel, at: url)
        }
    }
}

struct RecentProjectRow: View {
    let record: ProjectRecord
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(record.wordCount.formatted()) words")
                        Text("·")
                        Text(record.modifiedAt, style: .relative) + Text(" ago")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(record.url.path(percentEncoded: false))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
