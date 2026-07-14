import Foundation
import Network

/// A local TCP port forward established with the system `ssh` binary:
///   ssh -N -L 127.0.0.1:<local>:127.0.0.1:<remoteVNC> user@sshHost
///
/// VNC traffic is unencrypted, so tunnelling it through SSH is the recommended
/// way to reach a machine across an untrusted network.
final class SSHTunnel {
    private var process: Process?
    private var askpassURL: URL?
    let localPort: UInt16

    init() {
        // Ephemeral-ish local port; the OS will reject if busy and we retry.
        localPort = UInt16.random(in: 49_152...65_000)
    }

    func start(connection: Connection) async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args = [
            "-N",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=15",
            "-o", "ServerAliveInterval=15",
            "-p", String(connection.sshPort),
            "-L", "127.0.0.1:\(localPort):127.0.0.1:\(connection.vncPort)"
        ]
        if !connection.sshIdentityFile.isEmpty {
            args += ["-i", (connection.sshIdentityFile as NSString).expandingTildeInPath]
        }
        args.append("\(connection.sshUser)@\(connection.sshHost)")
        proc.arguments = args

        var env = ProcessInfo.processInfo.environment
        if !connection.sshPassword.isEmpty {
            let helper = try makeAskpass(password: connection.sshPassword)
            askpassURL = helper
            env["SSH_ASKPASS"] = helper.path
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = ":0"
        }
        proc.environment = env

        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()

        try proc.run()
        process = proc

        // Wait until the forwarded port accepts connections, surfacing ssh errors.
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if !proc.isRunning {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                let msg = String(data: data, encoding: .utf8) ?? "ssh exited"
                throw RFBError.handshakeFailed("SSH tunnel: \(msg.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if await portIsOpen(localPort) { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        throw RFBError.handshakeFailed("SSH tunnel did not become ready in time")
    }

    func stop() {
        process?.terminate()
        process = nil
        if let url = askpassURL { try? FileManager.default.removeItem(at: url) }
        unsetenv("REMOTE_SSH_PW")
    }

    private func makeAskpass(password: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("remote-askpass-\(UUID().uuidString).sh")
        // The password is passed via env to avoid embedding it in the script body.
        let script = "#!/bin/sh\nprintf '%s\\n' \"$REMOTE_SSH_PW\"\n"
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        setenv("REMOTE_SSH_PW", password, 1)
        return url
    }

    private func portIsOpen(_ port: UInt16) async -> Bool {
        await withCheckedContinuation { cont in
            let conn = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            var resumed = false
            let done: (Bool) -> Void = { ok in
                guard !resumed else { return }
                resumed = true
                conn.cancel()
                cont.resume(returning: ok)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: done(true)
                case .failed, .cancelled: done(false)
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { done(false) }
        }
    }
}
