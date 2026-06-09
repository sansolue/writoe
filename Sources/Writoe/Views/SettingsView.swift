import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @State private var showKey = false
    @State private var availableFonts: [String] = []
    @State private var loadingFonts = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Novel") {
                TextField("Title",  text: $store.novel.title)
                TextField("Author", text: $store.novel.author)
                TextField("Genre",  text: $store.novel.genre)
                TextField("Synopsis", text: $store.novel.synopsis, axis: .vertical)
                    .lineLimit(3...6)
                Stepper("Daily word goal: \(store.novel.dailyWordGoal)",
                        value: $store.novel.dailyWordGoal, in: 100...10000, step: 100)
            }

            Section("Theme") {
                ThemePicker(selected: store.writingTheme) { theme in
                    store.writingTheme = theme
                    store.saveTheme()
                }
            }

            Section("Writing") {
                // Language
                Picker("Language", selection: $store.novel.writingLanguage) {
                    ForEach(WritingLanguage.all) { lang in
                        Text("\(lang.nativeName)  —  \(lang.name)").tag(lang.id)
                    }
                }
                .onChange(of: store.novel.writingLanguage) { _, newLang in
                    store.save()
                    // Reset font to a sensible default for the new script
                    let langModel = WritingLanguage.find(id: newLang)
                    store.novel.fontName = WritingLanguage.defaultFont(for: langModel)
                    refreshFonts()
                }

                // Font (filtered by selected language's script)
                if loadingFonts {
                    HStack {
                        Text("Font").foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Picker("Font", selection: $store.novel.fontName) {
                        ForEach(availableFonts, id: \.self) { name in
                            Text(name)
                                .font(.custom(name, size: 14))
                                .tag(name)
                        }
                    }
                    .onChange(of: store.novel.fontName) { _, _ in store.save() }
                }

                // Size
                HStack {
                    Text("Size")
                    Spacer()
                    Stepper("\(Int(store.novel.fontSize)) pt",
                            value: $store.novel.fontSize, in: 11...28, step: 1)
                        .onChange(of: store.novel.fontSize) { _, _ in store.save() }
                }

                // RTL indicator (informational)
                if store.novel.isRTL {
                    Label("Right-to-left text direction active", systemImage: "arrow.right.to.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("AI Assistant") {
                HStack {
                    if showKey {
                        TextField("Anthropic API Key", text: $store.aiAPIKey)
                    } else {
                        SecureField("Anthropic API Key", text: $store.aiAPIKey)
                    }
                    Button(showKey ? "Hide" : "Show") { showKey.toggle() }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                }
                Link("Get an API key at console.anthropic.com",
                     destination: URL(string: "https://console.anthropic.com")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 580)
        .onAppear { refreshFonts() }
        .onChange(of: store.novel.title)         { _, _ in store.save() }
        .onChange(of: store.novel.author)        { _, _ in store.save() }
        .onChange(of: store.novel.genre)         { _, _ in store.save() }
        .onChange(of: store.novel.synopsis)      { _, _ in store.save() }
        .onChange(of: store.novel.dailyWordGoal) { _, _ in store.save() }
        .onChange(of: store.aiAPIKey)            { _, _ in store.saveAPIKey() }
    }

}

// MARK: - Theme picker

private struct ThemePicker: View {
    let selected: WritingTheme
    let onSelect: (WritingTheme) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(WritingTheme.allCases, id: \.self) { theme in
                ThemeCard(theme: theme, isSelected: selected == theme) {
                    onSelect(theme)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeCard: View {
    let theme: WritingTheme
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: theme.backgroundColor))
                        .frame(width: 72, height: 50)

                    VStack(spacing: 3) {
                        Text("Aa")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(Color(nsColor: theme.textColor))
                        Rectangle()
                            .fill(Color(nsColor: theme.textColor).opacity(0.25))
                            .frame(width: 36, height: 1.5)
                            .cornerRadius(0.75)
                        Rectangle()
                            .fill(Color(nsColor: theme.textColor).opacity(0.15))
                            .frame(width: 28, height: 1.5)
                            .cornerRadius(0.75)
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: 72, height: 50)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(4)
                            .frame(width: 72, height: 50)
                    } else if hovered {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 72, height: 50)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            .frame(width: 72, height: 50)
                    }
                }

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

extension SettingsView {
    func refreshFonts() {
        let lang = store.novel.writingLanguageModel
        loadingFonts = true
        Task.detached(priority: .userInitiated) {
            let fonts = WritingLanguage.fontNames(for: lang)
            await MainActor.run {
                availableFonts = fonts
                loadingFonts = false
                // Ensure the stored font is in the list; fall back to default
                if !fonts.contains(self.store.novel.fontName) {
                    self.store.novel.fontName = fonts.first
                        ?? WritingLanguage.defaultFont(for: lang)
                }
            }
        }
    }
}
