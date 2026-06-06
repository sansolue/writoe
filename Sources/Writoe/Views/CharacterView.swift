import SwiftUI

struct CharacterListView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        if let id = store.selectedCharacterID,
           let character = store.novel.characters.first(where: { $0.id == id }) {
            CharacterDetailView(character: character)
                .id(character.id) // recreate fully when switching characters
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Select a character")
                    .foregroundStyle(.secondary)
                Button("Add Character") {
                    store.addCharacter(named: "New Character")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CharacterDetailView: View {
    @Environment(AppStore.self) var store
    var character: Character
    @State private var draft: Character

    init(character: Character) {
        self.character = character
        _draft = State(initialValue: character)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                fieldSection
            }
            .padding(24)
        }
        // Auto-save on every change — no Save button needed
        .onChange(of: draft) { _, newDraft in
            store.updateCharacter(newDraft)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(roleColor(draft.role).opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(draft.name.isEmpty ? "?" : String(draft.name.prefix(1)))
                    .font(.largeTitle.bold())
                    .foregroundStyle(roleColor(draft.role))
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Character name", text: $draft.name)
                    .font(.title.bold())
                    .textFieldStyle(.plain)
                Picker("Role", selection: $draft.role) {
                    ForEach(CharacterRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Spacer()
        }
    }

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorField(label: "Description", text: $draft.description, minHeight: 80)
            EditorField(label: "Backstory", text: $draft.backstory, minHeight: 100)
            EditorField(label: "Notes", text: $draft.notes, minHeight: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text("Traits")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)
                TraitsEditor(traits: $draft.traits)
            }
        }
    }

    private func roleColor(_ role: CharacterRole) -> Color {
        switch role {
        case .protagonist: return .blue
        case .antagonist: return .red
        case .supporting: return .green
        case .minor: return .gray
        }
    }
}

struct EditorField: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        }
    }
}

struct TraitsEditor: View {
    @Binding var traits: [String]
    @State private var newTrait = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(traits) { trait in
                TraitTag(trait: trait) {
                    traits.removeAll { $0 == trait }
                }
            }
            HStack {
                TextField("Add trait…", text: $newTrait)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTrait() }
                Button("Add", action: addTrait)
                    .disabled(newTrait.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTrait() {
        let t = newTrait.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !traits.contains(t) else { return }
        traits.append(t)
        newTrait = ""
    }
}

struct TraitTag: View {
    let trait: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(trait)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .foregroundStyle(Color.accentColor)
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
        .frame(minHeight: 30)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        let spacing: CGFloat = 6

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if x + d.width > geo.size.width {
                            x = 0; y -= d.height + spacing
                        }
                        let result = x
                        x += d.width + spacing
                        return -result
                    }
                    .alignmentGuide(.top) { _ in -y }
            }
        }
    }
}
