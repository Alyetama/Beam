import SwiftUI

extension Color {
    static let accentIndigo = Color(red: 0.36, green: 0.42, blue: 0.95)
    static let accentIndigoDeep = Color(red: 0.28, green: 0.32, blue: 0.86)
    static let onlineGreen = Color(red: 0.30, green: 0.78, blue: 0.46)
    static let warnAmber = Color(red: 0.97, green: 0.72, blue: 0.27)
    static let dangerRed = Color(red: 0.93, green: 0.36, blue: 0.36)
}

/// A small coloured status indicator: a glowing dot plus a label.
struct StatusPill: View {
    let text: String
    let color: Color
    var pulsing: Bool = false

    @State private var animate = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: pulsing && animate ? 6 : 0)
                        .scaleEffect(pulsing && animate ? 1.8 : 1)
                        .opacity(pulsing && animate ? 0 : 1)
                )
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.6), in: Capsule())
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

/// Filled accent button used for the primary call to action.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: enabled ? [.accentIndigo, .accentIndigoDeep] : [.gray.opacity(0.4), .gray.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
