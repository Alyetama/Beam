import SwiftUI

struct ConnectionDetailView: View {
    let connection: Connection
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(spacing: 18) {
                        infoCard
                        actions
                    }
                    .padding(28)
                    .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.accentIndigo, .accentIndigoDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: connection.useSSHTunnel ? "lock.display" : "display")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.system(size: 19, weight: .bold))
                Text(connection.endpointDescription)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("VNC Host", connection.host.isEmpty ? "—" : connection.host, "network")
            Divider().padding(.leading, 46)
            infoRow("Display", ":\(connection.display)  (port \(connection.vncPort))", "number")
            Divider().padding(.leading, 46)
            infoRow("Security", connection.useSSHTunnel ? "Tunnelled over SSH" : "Direct VNC",
                    connection.useSSHTunnel ? "lock.fill" : "lock.open")
            if connection.useSSHTunnel {
                Divider().padding(.leading, 46)
                infoRow("SSH", "\(connection.sshUser)@\(connection.sshHost):\(connection.sshPort)", "terminal")
            }
            Divider().padding(.leading, 46)
            infoRow("Input", connection.viewOnly ? "View only" : "Mouse & keyboard",
                    connection.viewOnly ? "eye" : "cursorarrow.rays")
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func infoRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentIndigo)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                app.connect(connection)
            } label: {
                Label("Connect", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!connection.isValid)

            Button {
                app.edit(connection)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.quaternary, lineWidth: 1))

            Spacer()

            Button(role: .destructive) {
                store.delete(connection)
                app.selectedID = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .padding(11)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}
