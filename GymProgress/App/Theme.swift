import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.965, green: 0.969, blue: 0.976)
    static let card = Color.white
    static let text = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let secondaryText = Color(red: 0.42, green: 0.45, blue: 0.52)
    static let accent = Color(red: 0.10, green: 0.42, blue: 0.95)
    static let success = Color(red: 0.12, green: 0.65, blue: 0.36)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 12, y: 4)
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }
}
