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
                switch store.activeView {
                case .characters:
                    CharacterListView()
                case .corkboard:
                    CorkboardView()
                case .editor:
                    VStack(spacing: 0) {
                        if store.showGlobalFind {
                            GlobalFindView()
                                .frame(height: 280)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            Divider()
                        }
                        EditorView()
                    }
                    .animation(.easeInOut(duration: 0.2), value: store.showGlobalFind)
                }
            }
            .toolbar {
                // View mode toggle (Editor | Corkboard) — hidden in Characters view
                if store.activeView != .characters {
                    ToolbarItem(placement: .navigation) {
                        Picker("View", selection: Binding(
                            get: { store.activeView },
                            set: { store.activeView = $0 }
                        )) {
                            Label("Editor",    systemImage: "doc.text")          .tag(MainView.editor)
                            Label("Corkboard", systemImage: "rectangle.3.group") .tag(MainView.corkboard)
                        }
                        .pickerStyle(.segmented)
                        .help("Switch between editor and corkboard view")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { showInspector.toggle() }
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .help("Toggle Inspector")
                    .disabled(store.activeView == .corkboard)
                }
            }
            .inspector(isPresented: Binding(
                get: { showInspector && store.activeView != .corkboard },
                set: { showInspector = $0 }
            )) {
                InspectorView()
                    .inspectorColumnWidth(min: 180, ideal: 220, max: 260)
            }
        }
        .navigationTitle(store.novel.title)
        .navigationSubtitle(store.fileURL?.deletingLastPathComponent().path(percentEncoded: false) ?? "")
        .sheet(isPresented: Binding(
            get: { store.showExportSheet },
            set: { store.showExportSheet = $0 }
        )) {
            ExportSheet().environment(store)
        }
    }
}
