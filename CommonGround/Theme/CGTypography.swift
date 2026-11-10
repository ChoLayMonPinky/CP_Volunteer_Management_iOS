import SwiftUI

/// CommonGround type scale — Fraunces (display) + Manrope (UI).
enum CGTypography {
    /// Prefer named weights over `.weight()` chaining on variable fonts (cheaper layout).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        switch weight {
        case .semibold, .medium: return Font.custom("Fraunces-SemiBold", size: size)
        case .regular, .light: return Font.custom("Fraunces-Regular", size: size)
        default: return Font.custom("Fraunces-Bold", size: size)
        }
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black: return Font.custom("Manrope-Bold", size: size)
        case .semibold: return Font.custom("Manrope-SemiBold", size: size)
        case .medium: return Font.custom("Manrope-Medium", size: size)
        default: return Font.custom("Manrope-Regular", size: size)
        }
    }

    static let brandTitle = display(34, weight: .bold)
    static let screenTitle = display(28, weight: .bold)
    static let sectionTitle = display(22, weight: .semibold)
    static let cardTitle = sans(17, weight: .semibold)
    static let body = sans(15, weight: .regular)
    static let bodyEmphasis = sans(15, weight: .semibold)
    static let caption = sans(12, weight: .medium)
    static let label = sans(13, weight: .semibold)
    static let metric = display(26, weight: .bold)
}

extension View {
    /// Kept for call-site compatibility — no-op to avoid tab/scroll jank from staggered fades.
    func cgAppear(delay: Double = 0) -> some View {
        self
    }

    func cgPressable() -> some View {
        buttonStyle(CGSoftPressStyle())
    }
}

/// Light press feedback without implicit animation bindings (those were costing frame time).
struct CGSoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}
