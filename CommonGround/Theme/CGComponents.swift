import SwiftUI

enum CGSurfaceStyle {
    case card
    case quiet
    case elevated
}

struct CGSurface<Content: View>: View {
    var padding: CGFloat = 16
    var style: CGSurfaceStyle = .card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(border, lineWidth: style == .quiet ? 0 : 1)
            )
    }

    private var background: Color {
        switch style {
        case .card, .elevated: return AppColors.surface
        case .quiet: return AppColors.surface.opacity(0.55)
        }
    }

    private var border: Color {
        switch style {
        case .quiet: return .clear
        case .card, .elevated: return AppColors.hairline
        }
    }
}

struct CGRoleBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(CGTypography.sans(12, weight: .bold))
            .foregroundStyle(AppColors.onPrimaryContainer)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColors.primaryContainer, in: Capsule())
    }
}

struct CGFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(CGTypography.body)
            .padding(14)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: 1.5)
            )
    }
}

extension View {
    func cgField() -> some View {
        modifier(CGFieldModifier())
    }
}

struct CGPrimaryButton: View {
    let title: String
    var busy: Bool = false
    var enabled: Bool = true
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(.white)
                }
                Text(busy ? "\(title)…" : title)
                    .font(CGTypography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(CGSoftPressStyle())
        .disabled(!enabled || busy)
    }

    private var fill: Color {
        let base = destructive ? AppColors.danger : AppColors.primary
        return (enabled && !busy) ? base : base.opacity(0.45)
    }
}

struct CGBanner: View {
    enum Kind { case error, success, info }

    let kind: Kind
    let text: String

    var body: some View {
        Text(text)
            .font(CGTypography.caption)
            .foregroundStyle(foreground)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .error: return AppColors.danger
        case .success: return AppColors.onPrimaryContainer
        case .info: return AppColors.textPrimary
        }
    }

    private var background: Color {
        switch kind {
        case .error: return AppColors.dangerContainer
        case .success: return AppColors.primaryContainer
        case .info: return AppColors.amberContainer
        }
    }
}

struct CGEmptyState: View {
    let title: String
    let systemImage: String
    let message: String
    /// Denser layout for Duo cover / short sheets.
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryContainer)
                    .frame(width: compact ? 56 : 72, height: compact ? 56 : 72)
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 22 : 28, weight: .semibold))
                    .foregroundStyle(AppColors.accentText)
            }
            Text(title)
                .font(compact ? CGTypography.cardTitle : CGTypography.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(compact ? CGTypography.caption : CGTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, compact ? 12 : 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, compact ? 16 : 40)
    }
}

struct CGScreenBackground: View {
    var body: some View {
        // Flat fill only — gradient wash on every screen was redrawing on scroll and felt laggy.
        AppColors.canvas.ignoresSafeArea()
    }
}
