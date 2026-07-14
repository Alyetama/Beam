import Foundation
import Combine

/// Persists connection profiles to Application Support as JSON.
@MainActor
final class ConnectionStore: ObservableObject {
    @Published var connections: [Connection] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = support.appendingPathComponent("Beam", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("connections.json")
        // Migrate connections saved under the old "Remote" name.
        let legacy = support.appendingPathComponent("Remote/connections.json")
        if !FileManager.default.fileExists(atPath: fileURL.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.copyItem(at: legacy, to: fileURL)
        }
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else { return }
        connections = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        try? data.write(to: fileURL, options: .atomic)
        // Credentials are stored here; keep the file readable only by the owner.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func upsert(_ connection: Connection) {
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[idx] = connection
        } else {
            connections.append(connection)
        }
        save()
    }

    func delete(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        save()
    }
}
