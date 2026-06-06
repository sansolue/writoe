import SwiftUI

struct DistractionFreeView: View {
    @Environment(AppStore.self) var store
    @State private var text: String = ""
    @State private var showControls = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor).ignoresSafeArea()

            TextEditor(text: $text)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .lineSpacing(8)
                .frame(maxWidth: 680)
                .padding(.vertical, 60)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($focused)
                .onChange(of: text) { _, newValue in
                    store.updateSceneContent(newValue)
                }

            if showControls {
                overlayControls
            }
        }
        .onAppear {
            text = store.selectedScene?.content ?? ""
            focused = true
        }
        .onChange(of: store.selectedSceneID) { _, _ in
            text = store.selectedScene?.content ?? ""
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = hovering
            }
        }
        .ignoresSafeArea()
    }

    private var overlayControls: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    store.isDistractionFreeMode = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding()
            }
            Spacer()
            HStack {
                Spacer()
                Text("\(store.selectedScene?.wordCount ?? 0) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding()
            }
        }
        .transition(.opacity)
    }
}
