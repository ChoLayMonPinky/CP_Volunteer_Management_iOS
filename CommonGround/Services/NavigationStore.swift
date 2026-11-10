import SwiftUI

enum AppSection: String, Hashable, Identifiable {
    case home
    case events
    case hours
    case tasks
    case profile
    case checkIn
    case badges
    case notifications
    case letters
    case myActivities
    case attendance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .events: return "Events"
        case .hours: return "Hours"
        case .tasks: return "Tasks"
        case .profile: return "Profile"
        case .checkIn: return "Check-in"
        case .badges: return "Badges"
        case .notifications: return "Notifications"
        case .letters: return "Letters"
        case .myActivities: return "My Activities"
        case .attendance: return "Attendance"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .events: return "calendar"
        case .hours: return "clock.fill"
        case .tasks: return "checklist"
        case .profile: return "person.crop.circle.fill"
        case .checkIn: return "checkmark.seal.fill"
        case .badges: return "medal.fill"
        case .notifications: return "bell.fill"
        case .letters: return "doc.text.fill"
        case .myActivities: return "rectangle.stack.person.crop.fill"
        case .attendance: return "person.3.sequence.fill"
        }
    }

    /// Primary tabs shown in compact TabView (volunteer default).
    static var primaryTabs: [AppSection] {
        [.home, .events, .hours, .tasks, .profile]
    }

    static func primaryTabs(for session: AuthSession?) -> [AppSection] {
        guard let session else { return primaryTabs }
        if session.isAdmin {
            return [.home, .events, .hours, .attendance, .profile]
        }
        if session.isLeader {
            return [.home, .events, .attendance, .hours, .profile]
        }
        return [.home, .events, .checkIn, .hours, .profile]
    }

    static func moreSections(for session: AuthSession?) -> [AppSection] {
        guard let session else {
            return [.myActivities, .checkIn, .badges, .letters]
        }
        if session.isAdmin {
            return [.myActivities, .tasks, .checkIn, .badges, .letters]
        }
        if session.isLeader {
            return [.myActivities, .checkIn, .tasks, .badges, .letters]
        }
        return [.myActivities, .tasks, .badges, .letters]
    }

    func tabIndex(in session: AuthSession?) -> Int? {
        Self.primaryTabs(for: session).firstIndex(of: self)
    }
}

@MainActor
final class NavigationStore: ObservableObject {
    @Published var section: AppSection = .home
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
    /// Assistant opens as a sheet — not a floating FAB over content.
    @Published var showAssistant = false
    /// Notifications open as a compact inbox sheet — not a primary screen.
    @Published var showNotifications = false
    /// Unread badge for the shared notifications toolbar control.
    @Published var unreadNotifications = 0
    /// Avoid spamming `/notifications` from every toolbar instance.
    private var lastUnreadFetch: Date?

    func open(_ section: AppSection) {
        // Notifications is an overlay, not a destination.
        if section == .notifications {
            openNotifications()
            return
        }
        // Instant switch — animated section changes hitch on Duo's split shell.
        guard section != self.section else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.section = section
        }
    }

    func openTabIndex(_ index: Int, session: AuthSession? = nil) {
        let tabs = AppSection.primaryTabs(for: session)
        guard tabs.indices.contains(index) else { return }
        open(tabs[index])
    }

    func openAssistant() {
        guard !showAssistant || showNotifications else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showNotifications = false
            showAssistant = true
        }
    }

    func closeAssistant() {
        showAssistant = false
    }

    func openNotifications() {
        guard !showNotifications || showAssistant else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showAssistant = false
            showNotifications = true
        }
    }

    func closeNotifications() {
        showNotifications = false
    }

    func setUnreadNotifications(_ count: Int) {
        let next = max(0, count)
        guard next != unreadNotifications else { return }
        unreadNotifications = next
    }

    /// Returns true when a network refresh is worthwhile (debounced).
    func shouldRefreshUnread(minInterval: TimeInterval = 45) -> Bool {
        guard let last = lastUnreadFetch else { return true }
        return Date().timeIntervalSince(last) >= minInterval
    }

    func markUnreadFetched() {
        lastUnreadFetch = Date()
    }

    func reset() {
        section = .home
        columnVisibility = .all
        showAssistant = false
        showNotifications = false
        unreadNotifications = 0
        lastUnreadFetch = nil
    }
}
