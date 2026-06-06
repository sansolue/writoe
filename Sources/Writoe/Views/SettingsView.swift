import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @State private var apiKeyInput: String = ""
    @State private var showKey = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Novel") {
                TextField("Title", text: $store.novel.title)
                TextField("Author", text: $store.novel.author)
                TextField("Genre", text: $store.novel.genre)
                TextField("Synopsis", text: $store.novel.synopsis, axis: .vertical)
                    .lineLimit(3...6)
                Stepper("Daily word goal: \(store.novel.dailyWordGoal)", value: $store.novel.dailyWordGoal, in: 100...10000, step: 100)
            }

            Section("AI Assistant") {
                HStack {
                    if showKey {
                        TextField("Anthropic API Key", text: $store.aiAPIKey)
                    } else {
                        SecureField("Anthropic API Key", text: $store.aiAPIKey)
                    }
                    Button(showKey ? "Hide" : "Show") {
                        showKey.toggle()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                Link("Get an API key at console.anthropic.com",
                     destination: URL(string: "https://console.anthropic.com")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .onChange(of: store.novel.title) { _, _ in store.save() }
        .onChange(of: store.novel.dailyWordGoal) { _, _ in store.save() }
    }
}
