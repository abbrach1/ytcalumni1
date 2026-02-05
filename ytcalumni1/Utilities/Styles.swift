import SwiftUI

// MARK: - Custom Colors
extension Color {
    static let navy = Color(red: 0.1, green: 0.15, blue: 0.25)
    static let navyLight = Color(red: 0.15, green: 0.2, blue: 0.35)
    static let gold = Color(red: 0.85, green: 0.65, blue: 0.25)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let creamDark = Color(red: 0.94, green: 0.91, blue: 0.86)
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isDisabled ? Color.navy.opacity(0.5) : Color.navy)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(.navy)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gold.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.gold)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func customTextField() -> some View {
        modifier(CustomTextFieldStyle())
    }
}

// MARK: - Card Style
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Hebrew Font Support
extension Font {
    static func hebrew(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }
    
    static func serifHeadline() -> Font {
        return .system(size: 28, weight: .bold, design: .serif)
    }
    
    static func serifTitle() -> Font {
        return .system(size: 22, weight: .semibold, design: .serif)
    }
}
