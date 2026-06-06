import SwiftUI

struct AIPanelView: View {
    @Environment(AppStore.self) var store
    @Binding var text: String
    @State private var result: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAction: AIService.AIAction = .continueWriting
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Writing Assistant")
                .font(.title2.bold())

            Picker("Action", selection: $selectedAction) {
                Text("Continue Writing").tag(AIService.AIAction.continueWriting)
                Text("Rewrite").tag(AIService.AIAction.rewrite)
                Text("Brainstorm").tag(AIService.AIAction.brainstorm)
                Text("Improve Dialogue").tag(AIService.AIAction.improveDialogue)
            }
            .pickerStyle(.segmented)

            if isLoading {
                ProgressView("Thinking…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if !result.isEmpty {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .serif))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxHeight: 300)

                HStack {
                    Button("Use This") {
                        if selectedAction == .continueWriting {
                            text += "\n\n" + result
                        } else {
                            text = result
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Regenerate") { generate() }
                    Spacer()
                    Button("Cancel") { dismiss() }
                }
            } else {
                Button("Generate") { generate() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                if store.aiAPIKey.isEmpty {
                    Label("Add your Anthropic API key in Settings to use AI features.", systemImage: "key")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 540, height: 420)
    }

    private func generate() {
        isLoading = true
        errorMessage = nil
        let service = AIService(apiKey: store.aiAPIKey)
        let context = "Title: \(store.novel.title). Genre: \(store.novel.genre). Synopsis: \(store.novel.synopsis)"
        let inputText = text.suffix(2000).description

        Task {
            do {
                result = try await service.perform(selectedAction, on: inputText, novelContext: context)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
