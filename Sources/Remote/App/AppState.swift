import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedID: UUID?
    @Published var editing: Connection?
    @Published var isNewConnection = false
    @Published var session: RFBClient?

    func newConnection() {
        editing = Connection()
        isNewConnection = true
    }

    func edit(_ connection: Connection) {
        editing = connection
        isNewConnection = false
    }

    func connect(_ connection: Connection) {
        session?.stop()
        let client = RFBClient(connection: connection)
        session = client
        client.start()
    }

    func disconnect() {
        session?.stop()
        session = nil
    }
}
