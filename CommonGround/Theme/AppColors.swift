import SwiftUI
import UIKit

/// CommonGround brand tokens — keep in sync with brand/colors.json
/// and Android Color.kt / web `.cg-role-portal`.
enum AppColors {
    static let primary = Color(hex: 0x059669)
    static let primaryStrong = Color(hex: 0x047857)
    /// Readable emerald accent on both light and dark surfaces.
    static let accentText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1) // #34D399
            : UIColor(red: 0.02, green: 0.47, blue: 0.34, alpha: 1) // #047857
    })
    static let primaryContainer = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.024, green: 0.373, blue: 0.275, alpha: 1) // #065F46
            : UIColor(red: 0.820, green: 0.980, blue: 0.898, alpha: 1) // #D1FAE5
    })
    static let onPrimaryContainer = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.820, green: 0.980, blue: 0.898, alpha: 1) // #D1FAE5
            : UIColor(red: 0.024, green: 0.373, blue: 0.275, alpha: 1) // #065F46
    })

    static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.973, green: 0.980, blue: 0.988, alpha: 1) // #F8FAFC
            : UIColor(red: 0.047, green: 0.102, blue: 0.078, alpha: 1) // #0C1A14
    })
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.796, green: 0.835, blue: 0.882, alpha: 1) // #CBD5E1
            : UIColor(red: 0.357, green: 0.420, blue: 0.388, alpha: 1) // #5B6B63
    })
    static let textMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1)
            : UIColor(red: 0.518, green: 0.580, blue: 0.545, alpha: 1) // #84948B
    })

    static let amber = Color(hex: 0xD97706)
    static let amberContainer = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.20, blue: 0.05, alpha: 1)
            : UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1)
    })
    static let danger = Color(hex: 0xDC2626)
    static let dangerContainer = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.08, blue: 0.08, alpha: 1)
            : UIColor(red: 0.996, green: 0.95, blue: 0.95, alpha: 1)
    })

    static let splashGradient = LinearGradient(
        colors: [Color(hex: 0x047857), Color(hex: 0x059669), Color(hex: 0x10B981)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x059669), Color(hex: 0x047857)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var canvas: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.043, green: 0.078, blue: 0.067, alpha: 1) // #0B1411
                : UIColor(red: 0.957, green: 0.969, blue: 0.961, alpha: 1) // #F4F7F5
        })
    }

    static var surface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.125, blue: 0.110, alpha: 1) // #15201C
                : UIColor.white
        })
    }

    static var hairline: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.165, green: 0.231, blue: 0.204, alpha: 1) // #2A3B34
                : UIColor(red: 0.773, green: 0.831, blue: 0.796, alpha: 1) // #C5D4CB
        })
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
