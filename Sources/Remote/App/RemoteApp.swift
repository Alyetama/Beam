import SwiftUI

@main
struct RemoteApp: App {
    @StateObject private var store = ConnectionStore()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
                .frame(minWidth: 940, minHeight: 620)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection…") { appState.newConnection() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Disconnect") { appState.disconnect() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .disabled(appState.session == nil)
            }
        }
    }
}
