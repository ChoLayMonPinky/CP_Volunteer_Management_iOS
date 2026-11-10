import SwiftUI

/// Layout modes for iPhone Duo / foldable / iPad wide canvases.
enum DuoMode: String, Equatable {
    /// Single column — folded phone / Pro Max portrait / compact width.
    case compact
    /// Two-pane — unfolded Duo / regular width.
    case duo
    /// Extra-wide — large unfold / Stage Manager / desktop-class.
    case expansive

    var usesSplitShell: Bool { self != .compact }

    var sidebarWidth: CGFloat {
        switch self {
        case .compact: return 0
        case .duo: return 248
        case .expansive: return 288
        }
    }

    /// Bottom list padding (FAB removed — only tab bar / home indicator).
    var chatClearance: CGFloat {
        switch self {
        case .compact: return 28
        case .duo, .expansive: return 24
        }
    }

    func chatClearance(for canvasSize: CGSize) -> CGFloat {
        if DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height) {
            return 24
        }
        return chatClearance
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 16
        case .duo: return 20
        case .expansive: return 24
        }
    }

    var gridColumnCount: Int {
        switch self {
        case .compact: return 2
        case .duo: return 3
        case .expansive: return 4
        }
    }

    var eventsListWidth: CGFloat {
        switch self {
        case .compact: return 0
        case .duo: return 300
        case .expansive: return 340
        }
    }
}

/// Which physical Duo / phone surface the window is on.
enum DuoSurface: String, Equatable {
    /// Folded cover LCD (~466×678 @3x on iPhone Duo simulator).
    case cover
    /// Standard compact phone (e.g. 18 Pro Max portrait).
    case phone
    /// Unfolded inner Duo canvas.
    case inner
    /// Extra-wide / Stage Manager.
    case expansive
}

enum DuoLayout {
    /// Unfolded Duo / dual-pane ready (slightly lower so Duo gets the labeled split sooner).
    static let duoBreakpoint: CGFloat = 620
    static let expansiveBreakpoint: CGFloat = 1100
    static let minSplitHeight: CGFloat = 520
    /// Duo cover / outer display is short and narrow (see sim LCD ~1398×2034 @3×).
    static let coverMaxWidth: CGFloat = 520
    static let coverMaxHeight: CGFloat = 740

    static func mode(
        width: CGFloat,
        height: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> DuoMode {
        // Cover / outer must stay single-column even if size class is oddly .regular.
        if isCoverDisplay(width: width, height: height) { return .compact }

        let tallEnough = height >= minSplitHeight
        if width >= expansiveBreakpoint && tallEnough { return .expansive }
        if width >= duoBreakpoint && tallEnough { return .duo }
        // iPhone Duo inner / iPad often report regular width with a mid-size canvas.
        if horizontalSizeClass == .regular, width >= 500, tallEnough {
            return .duo
        }
        return .compact
    }

    /// True for the folded outer cover (not the unfolded inner display).
    static func isCoverDisplay(width: CGFloat, height: CGFloat) -> Bool {
        let shortSide = min(width, height)
        let longSide = max(width, height)
        return shortSide <= coverMaxWidth && longSide <= coverMaxHeight
    }

    static func surface(
        width: CGFloat,
        height: CGFloat,
        mode: DuoMode
    ) -> DuoSurface {
        if isCoverDisplay(width: width, height: height) { return .cover }
        switch mode {
        case .expansive: return .expansive
        case .duo: return .inner
        case .compact: return .phone
        }
    }

    static func gridColumns(for mode: DuoMode, width: CGFloat) -> [GridItem] {
        let spacing: CGFloat = mode == .compact ? 12 : 14
        let count: Int
        if mode == .expansive || width >= 900 {
            count = 4
        } else if mode == .duo || width >= 520 {
            count = 3
        } else {
            count = 2
        }
        return Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: count
        )
    }

    static func chatPanelSize(for size: CGSize, mode: DuoMode) -> CGSize {
        let surface = surface(width: size.width, height: size.height, mode: mode)
        let maxW: CGFloat
        let maxH: CGFloat
        switch surface {
        case .cover:
            // Keep the sheet inside the short cover display above the FAB + tab bar.
            maxW = min(320, max(240, size.width - 24))
            maxH = min(360, max(260, size.height * 0.48))
        case .phone:
            maxW = min(340, max(280, size.width - 28))
            maxH = min(460, max(340, size.height * 0.58))
        case .inner:
            maxW = min(360, max(280, size.width * 0.38))
            maxH = min(480, max(340, size.height * 0.58))
        case .expansive:
            maxW = min(400, max(300, size.width * 0.34))
            maxH = min(520, max(360, size.height * 0.6))
        }
        return CGSize(width: maxW, height: maxH)
    }

    /// FAB padding relative to the shell overlay (outside TabView / SplitView safe areas).
    /// Handles Duo **outer cover** and **inner unfold**, plus Pro Max.
    static func chatFabInsets(
        mode: DuoMode,
        canvasSize: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> (trailing: CGFloat, bottom: CGFloat) {
        let surface = surface(
            width: canvasSize.width,
            height: canvasSize.height,
            mode: mode
        )
        switch surface {
        case .cover:
            // Cover always uses a bottom tab bar — never treat as trailing sidebar
            // (Duo outer can still report `.regular` size class).
            return (trailing: 16, bottom: 84)
        case .inner, .expansive:
            // Leading sidebar / split — pin to detail bottom-trailing.
            return (trailing: 20, bottom: 28)
        case .phone:
            let landscape = canvasSize.width > canvasSize.height + 8
            // Only use side-rail insets when the canvas is actually wide enough.
            let sideRail = landscape
                || (horizontalSizeClass == .regular && canvasSize.width >= 700)
            if sideRail {
                return (trailing: 78, bottom: 24)
            }
            return (trailing: 18, bottom: 90)
        }
    }

    static func chatFabSize(for canvasSize: CGSize, mode: DuoMode) -> CGFloat {
        let surface = surface(width: canvasSize.width, height: canvasSize.height, mode: mode)
        return surface == .cover ? 50 : 56
    }

    /// Coarse snap so fold/resize doesn't republish environment on every pixel.
    static func quantized(_ size: CGSize) -> CGSize {
        let step: CGFloat = 16
        return CGSize(
            width: (size.width / step).rounded() * step,
            height: (size.height / step).rounded() * step
        )
    }
}

private struct DuoModeKey: EnvironmentKey {
    static let defaultValue: DuoMode = .compact
}

private struct DuoCanvasSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = CGSize(width: 390, height: 844)
}

extension EnvironmentValues {
    var duoMode: DuoMode {
        get { self[DuoModeKey.self] }
        set { self[DuoModeKey.self] = newValue }
    }

    var duoCanvasSize: CGSize {
        get { self[DuoCanvasSizeKey.self] }
        set { self[DuoCanvasSizeKey.self] = newValue }
    }
}

/// Publishes Duo mode from window geometry without mutating `@State` during layout.
struct DuoModeReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: (DuoMode, CGSize) -> Content
    /// Last non-degenerate canvas — keyboard inset must not collapse the shell to 0×h.
    @State private var lockedCanvas = CGSize(width: 390, height: 844)

    var body: some View {
        GeometryReader { geo in
            let raw = geo.size
            let usable = Self.stableSize(raw, fallback: lockedCanvas)
            let size = DuoLayout.quantized(usable)
            let mode = DuoLayout.mode(
                width: size.width,
                height: size.height,
                horizontalSizeClass: horizontalSizeClass
            )
            ZStack {
                // Full-bleed canvas only — don't expand layout into landscape safe areas.
                AppColors.canvas.ignoresSafeArea()
                content(mode, size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.duoMode, mode)
                    .environment(\.duoCanvasSize, size)
                    // Don't animate shell morphs driven by geometry thrash.
                    .transaction { $0.animation = nil }
            }
            // Never publish a 0-height/width frame — that yields “Conversion error!” and
            // dead TextFields when the keyboard resizes the GeometryReader on Duo cover.
            .frame(
                width: max(usable.width, 1),
                height: max(usable.height, 1)
            )
            .onAppear { lockedCanvas = size }
            .onChange(of: size) { _, next in
                if next.width > 32, next.height > 32 {
                    lockedCanvas = next
                }
            }
        }
        // Keyboard must not shrink this reader — otherwise cover Auth/Profile get 0-tall
        // rects and UIKit coordinate conversion + TUIPredictionViewCell constraints blow up.
        .ignoresSafeArea(.keyboard)
    }

    /// Reject transient zero / near-zero proposals (keyboard show/hide, fold thrash).
    private static func stableSize(_ raw: CGSize, fallback: CGSize) -> CGSize {
        guard raw.width > 32, raw.height > 32 else { return fallback }
        return raw
    }
}
