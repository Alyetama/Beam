import Foundation

/// A saved remote-desktop connection profile.
struct Connection: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = "New Connection"

    /// VNC host. When `useSSHTunnel` is on this is reached *through* the SSH host.
    var host: String = ""
    /// VNC display number. The TCP port is 5900 + display (e.g. display 0 -> 5900).
    var display: Int = 0
    var vncPassword: String = ""

    /// View-only disables all input forwarding.
    var viewOnly: Bool = false
    /// Map the macOS ⌘ key to Ctrl on the remote (handy for shell shortcuts).
    var mapCommandToControl: Bool = true

    // MARK: SSH tunnel (optional, recommended — VNC itself is unencrypted)
    var useSSHTunnel: Bool = false
    var sshHost: String = ""
    var sshPort: Int = 22
    var sshUser: String = ""
    /// Optional explicit identity file. Empty -> rely on ssh-agent / default keys.
    var sshIdentityFile: String = ""
    /// Optional password for the SSH login (forwarded via an askpass helper).
    var sshPassword: String = ""

    var vncPort: Int { 5900 + display }

    /// Host:port actually shown to the user for status.
    var endpointDescription: String {
        useSSHTunnel ? "\(sshUser)@\(sshHost) → \(host):\(vncPort)" : "\(host):\(vncPort)"
    }

    var isValid: Bool {
        if useSSHTunnel {
            return !sshHost.isEmpty && !sshUser.isEmpty && !host.isEmpty
        }
        return !host.isEmpty
    }
}
