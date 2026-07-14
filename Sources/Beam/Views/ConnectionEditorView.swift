import SwiftUI

struct ConnectionEditorView: View {
    @State private var draft: Connection
    let isNew: Bool

    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    init(connection: Connection, isNew: Bool) {
        _draft = State(initialValue: connection)
        self.isNew = isNew
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Connection" : "Edit Connection")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Divider()

            Form {
                Section("General") {
                    TextField("Name", text: $draft.name, prompt: Text("My Ubuntu Desktop"))
                }

                Section {
                    TextField("VNC Host", text: $draft.host,
                              prompt: Text(draft.useSSHTunnel ? "localhost" : "192.168.1.50"))
                    .autocorrectionDisabled()
                    Stepper(value: $draft.display, in: 0...99) {
                        HStack {
                            Text("Display")
                            Spacer()
                            Text(verbatim: ":\(draft.display) · port \(draft.vncPort)")
                                .foregroundStyle(.secondary).font(.callout.monospacedDigit())
                        }
                    }
                    SecureField("VNC Password", text: $draft.vncPassword,
                                prompt: Text("Leave blank if none"))
                } header: {
                    Text("Display")
                } footer: {
                    Text(draft.useSSHTunnel
                         ? "Host is resolved on the SSH server — usually localhost."
                         : "The Ubuntu machine's address on your network.")
                    .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Tunnel over SSH", isOn: $draft.useSSHTunnel.animation())
                    if draft.useSSHTunnel {
                        TextField("SSH Host", text: $draft.sshHost, prompt: Text("server.example.com"))
                            .autocorrectionDisabled()
                        TextField("SSH User", text: $draft.sshUser, prompt: Text("ubuntu"))
                            .autocorrectionDisabled()
                        Stepper(value: $draft.sshPort, in: 1...65535) {
                            HStack { Text("SSH Port"); Spacer()
                                Text(verbatim: "\(draft.sshPort)").foregroundStyle(.secondary).font(.callout.monospacedDigit()) }
                        }
                        TextField("Identity File", text: $draft.sshIdentityFile,
                                  prompt: Text("~/.ssh/id_ed25519 (optional)"))
                            .autocorrectionDisabled()
                        SecureField("SSH Password", text: $draft.sshPassword,
                                    prompt: Text("Optional — keys preferred"))
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("VNC traffic is unencrypted. Tunnelling over SSH is strongly recommended across untrusted networks.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Input") {
                    Toggle("View only", isOn: $draft.viewOnly)
                    Toggle("Map ⌘ to Ctrl on remote", isOn: $draft.mapCommandToControl)
                        .disabled(draft.viewOnly)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isNew ? "Add" : "Save") {
                    store.upsert(draft)
                    app.selectedID = draft.id
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 560)
    }
}
