import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var app: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(sidebarVisible: columnVisibility != .detailOnly)
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 340)
        } detail: {
            DetailView()
        }
        .sheet(item: $app.editing) { connection in
            ConnectionEditorView(connection: connection, isNew: app.isNewConnection)
        }
        // Collapse the sidebar while connected; restore it on disconnect.
        .onChange(of: app.session == nil) { _, disconnected in
            withAnimation(.easeInOut(duration: 0.25)) {
                columnVisibility = disconnected ? .all : .detailOnly
            }
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            if let session = app.session {
                SessionView(client: session)
            } else if let id = app.selectedID,
                      let connection = store.connections.first(where: { $0.id == id }) {
                ConnectionDetailView(connection: connection)
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
