import SwiftUI

struct DistractionFreeView: View {
    @Environment(AppStore.self) var store
    @State private var showControls = false

    var body: some View {
        ZStack {
            store.writingTheme.swiftUIBackground.ignoresSafeArea()

            // Centered writing column, max 680pt wide
            GeometryReader { geo in
                let hPad = max(60, (geo.size.width - 680) / 2)
                WritingTextView(
                    text: Binding(get: { store.selectedScene?.content ?? "" }, set: { _ in }),
                    sceneID: store.selectedSceneID,
                    fontName: store.novel.fontName,
                    fontSize: store.novel.fontSize + 2,
                    isRTL: store.novel.isRTL,
                    spellCheckLanguage: store.novel.writingLanguage,
                    theme: store.writingTheme,
                    horizontalPadding: hPad,
                    verticalPadding: 60,
                    onTextChange: { store.updateSceneContent($0) }
                )
            }

            if showControls { overlayControls }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { showControls = hovering }
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
