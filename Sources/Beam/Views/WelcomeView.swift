import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor),
                                    Color(nsColor: .underPageBackgroundColor)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [.accentIndigo, .accentIndigoDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .shadow(color: .accentIndigo.opacity(0.4), radius: 22, y: 10)
                    Image(systemName: "display")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 7) {
                    Text("Beam")
                        .font(.system(size: 30, weight: .bold))
                    Text("A clean, native remote desktop for your Ubuntu machine.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    app.newConnection()
                } label: {
                    Label("New Connection", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: 420)
            .padding()
        }
    }
}
