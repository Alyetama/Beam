import SwiftUI

struct SessionView: View {
    @ObservedObject var client: RFBClient
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ZStack {
                Color.black
                VNCScreenView(client: client)
                overlay
            }
        }
        .background(Color.black)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(client.connection.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(client.desktopName.isEmpty ? client.connection.endpointDescription : client.desktopName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            StatusPill(text: status.text, color: status.color, pulsing: status.pulsing)

            Spacer()

            if case .connected = client.state {
                HStack(spacing: 14) {
                    metric("\(Int(client.remoteSize.width))×\(Int(client.remoteSize.height))", "rectangle.dashed")
                    metric("\(client.fps) fps", "speedometer")
                }
                .foregroundStyle(.secondary)
            }

            Button {
                NSApp.keyWindow?.toggleFullScreen(nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("Toggle full screen")
            .disabled(client.state != .connected)

            Button {
                app.disconnect()
            } label: {
                Label("Disconnect", systemImage: "stop.fill")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.dangerRed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func metric(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 12, weight: .medium).monospacedDigit())
        }
    }

    // MARK: Status mapping

    private var status: (text: String, color: Color, pulsing: Bool) {
        switch client.state {
        case .idle:            return ("Idle", .secondary, false)
        case .connecting:      return ("Connecting…", .warnAmber, true)
        case .authenticating:  return ("Authenticating…", .warnAmber, true)
        case .connected:       return ("Connected", .onlineGreen, false)
        case .failed:          return ("Failed", .dangerRed, false)
        case .disconnected:    return ("Disconnected", .secondary, false)
        }
    }

    // MARK: Overlays

    @ViewBuilder private var overlay: some View {
        switch client.state {
        case .connecting, .authenticating, .idle:
            connectingOverlay
        case .failed(let message):
            failedOverlay(message)
        default:
            EmptyView()
        }
    }

    private var connectingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(status.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(client.connection.endpointDescription)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
    }

    private func failedOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.dangerRed)
            Text("Couldn't connect")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button {
                    app.connect(client.connection)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Close") { app.disconnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.white)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
    }
}
