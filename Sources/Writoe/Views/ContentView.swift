import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) var store
    @State private var showInspector = true

    var body: some View {
        if store.isDistractionFreeMode {
            DistractionFreeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            mainLayout
        }
    }

    private var mainLayout: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            Group {
                if store.showCharacters {
                    CharacterListView()
                } else {
                    EditorView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { showInspector.toggle() }
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .help("Toggle Inspector")
                }
            }
            .inspector(isPresented: $showInspector) {
                InspectorView()
                    .inspectorColumnWidth(min: 180, ideal: 220, max: 260)
            }
        }
        .navigationTitle(store.novel.title)
        .navigationSubtitle(store.fileURL?.deletingLastPathComponent().path(percentEncoded: false) ?? "")
    }
}
