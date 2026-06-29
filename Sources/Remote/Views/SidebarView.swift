import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var app: AppState
    var sidebarVisible = true

    var body: some View {
        List(selection: $app.selectedID) {
            Section {
                ForEach(store.connections) { connection in
                    ConnectionRow(connection: connection)
                        .tag(connection.id)
                        .contextMenu {
                            Button("Connect") { app.connect(connection) }
                            Button("Edit…") { app.edit(connection) }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(connection) }
                        }
                }
            } header: {
                Text("Connections")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentIndigo)
                Text("Beam")
                    .font(.system(size: 12.5, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
        .toolbar {
            if sidebarVisible {
                ToolbarItem(placement: .primaryAction) {
                    Button { app.newConnection() } label: {
                        Image(systemName: "plus")
                    }
                    .help("New connection")
                }
            }
        }
        .overlay {
            if store.connections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text("No connections yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Add one") { app.newConnection() }
                        .buttonStyle(.link)
                }
            }
        }
    }
}

private struct ConnectionRow: View {
    let connection: Connection

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [.accentIndigo, .accentIndigoDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: connection.useSSHTunnel ? "lock.fill" : "display")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(connection.name.isEmpty ? "Untitled" : connection.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(connection.endpointDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
