import SwiftUI

struct InspectorView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statsSection
            Divider().padding(.vertical, 8)
            sceneNotesSection
        }
        .padding(12)
        .frame(minWidth: 200)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)

            statRow(label: "Novel total", value: "\(store.novel.totalWordCount) words")
            statRow(label: "Scene", value: "\(store.selectedScene?.wordCount ?? 0) words")
            statRow(label: "Today", value: "\(store.todayWordCount) / \(store.novel.dailyWordGoal)")

            let progress = min(Double(store.todayWordCount) / Double(max(store.novel.dailyWordGoal, 1)), 1.0)
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(progress >= 1.0 ? .green : .accentColor)
                Text(progress >= 1.0 ? "Daily goal reached!" : "\(store.novel.dailyWordGoal - store.todayWordCount) words to go")
                    .font(.caption2)
                    .foregroundStyle(progress >= 1.0 ? .green : .secondary)
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
    }

    private var sceneNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scene Notes")
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)

            if store.selectedScene != nil {
                SceneNotesField()
            } else {
                Text("No scene selected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SceneNotesField: View {
    @Environment(AppStore.self) var store

    var body: some View {
        TextEditor(text: Binding(
            get: { store.selectedScene?.synopsis ?? "" },
            set: { store.updateSceneSynopsis($0) }
        ))
        .font(.caption)
        .frame(minHeight: 80)
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}
