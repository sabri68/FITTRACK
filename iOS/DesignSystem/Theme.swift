import SwiftUI

/// FitTrack visual identity: clean white surfaces, a warm coral accent and soft cards.
enum Theme {
    static let accent = Color("AccentColor")
    static let accentGradient = LinearGradient(colors: [Color(red: 1.0, green: 0.42, blue: 0.24),
                                                        Color(red: 0.91, green: 0.12, blue: 0.39)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    static let protein = Color(red: 0.20, green: 0.48, blue: 0.96)
    static let carbs = Color(red: 0.98, green: 0.65, blue: 0.10)
    static let fat = Color(red: 0.62, green: 0.36, blue: 0.93)
    static let positive = Color(red: 0.16, green: 0.72, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.55, blue: 0.10)

    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtleFill = Color(uiColor: .tertiarySystemFill)

    static let cornerRadius: CGFloat = 22
    static let spacing: CGFloat = 16
}

extension View {
    /// Rounded card container used across the app.
    func cardStyle(padding: CGFloat = Theme.spacing) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
            )
    }

    /// Hides the keyboard (used by "OK" toolbar buttons on numeric fields).
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.35)))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Capsule().fill(Theme.accent.opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
