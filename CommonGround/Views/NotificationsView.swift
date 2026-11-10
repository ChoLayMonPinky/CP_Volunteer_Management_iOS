import SwiftUI

/// Compact inbox presented from the toolbar bell — not a primary navigation screen.
struct NotificationsInboxSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoCanvasSize) private var canvasSize
    @State private var items: [ApiNotification] = []
    @State private var error: String?
    @State private var loading = false

    private var hasUnread: Bool {
        items.contains { $0.read != true }
    }

    private var unreadCount: Int {
        items.filter { $0.read != true }.count
    }

    /// Duo outer cover is short/narrow — use denser chrome.
    private var isCover: Bool {
        DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height)
    }

    var body: some View {
        NavigationStack {
            content
                .background(AppColors.canvas)
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Never leave an empty ToolbarItem — EmptyView still registers 0×0 layout on Duo.
                    if hasUnread {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(isCover ? "Read all" : "Mark all read") {
                                Task { await markAll() }
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            navigation.closeNotifications()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if loading && items.isEmpty {
            ProgressView("Loading…")
                .tint(AppColors.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error, items.isEmpty {
            CGEmptyState(
                title: "Couldn’t load",
                systemImage: "exclamationmark.triangle.fill",
                message: error,
                compact: isCover
            )
            .padding(.horizontal, isCover ? 8 : 0)
        } else if items.isEmpty {
            CGEmptyState(
                title: "You’re all caught up",
                systemImage: "bell.slash",
                message: isCover
                    ? "New updates will show here."
                    : "New updates from your organization will appear here.",
                compact: isCover
            )
            .padding(.horizontal, isCover ? 8 : 0)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: isCover ? 10 : 12) {
                    if unreadCount > 0 {
                        Text("\(unreadCount) unread")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.accentText)
                            .padding(.horizontal, 4)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            Task { await markRead(item) }
                        } label: {
                            NotificationRow(item: item, compact: isCover)
                        }
                        .buttonStyle(.plain)

                            if index < items.count - 1 {
                                Divider()
                                    .overlay(AppColors.hairline)
                                    .padding(.leading, isCover ? 52 : 60)
                            }
                        }
                    }
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.hairline, lineWidth: 1)
                    )
                }
                .padding(.horizontal, isCover ? 12 : 16)
                .padding(.top, isCover ? 4 : 8)
                .padding(.bottom, isCover ? 12 : 20)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func load() async {
        loading = items.isEmpty
        error = nil
        defer { loading = false }

        guard let token = authStore.session?.accessToken else {
            items = []
            navigation.setUnreadNotifications(0)
            return
        }
        do {
            let page = try await APIClient.shared.myNotifications(token: token)
            items = page.items ?? []
            navigation.markUnreadFetched()
            navigation.setUnreadNotifications(
                page.unreadCount ?? items.filter { $0.read != true }.count
            )
        } catch {
            self.error = authStore.friendlyMessage(for: error)
            navigation.markUnreadFetched()
        }
    }

    private func markRead(_ item: ApiNotification) async {
        guard item.read != true else { return }
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = items[idx].markedRead()
            navigation.setUnreadNotifications(items.filter { $0.read != true }.count)
        }
        guard let token = authStore.session?.accessToken else { return }
        _ = try? await APIClient.shared.markNotificationRead(id: item.id, token: token)
    }

    private func markAll() async {
        items = items.map { $0.markedRead() }
        navigation.setUnreadNotifications(0)
        guard let token = authStore.session?.accessToken else { return }
        try? await APIClient.shared.markAllNotificationsRead(token: token)
    }
}

/// Legacy name — inbox is a sheet from the shell, not a pushed screen.
typealias NotificationsView = NotificationsInboxSheet

private struct NotificationRow: View {
    let item: ApiNotification
    var compact: Bool = false

    private var isUnread: Bool { item.read != true }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 12) {
            typeIcon
            VStack(alignment: .leading, spacing: compact ? 3 : 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title ?? "Notification")
                        .font((compact ? Font.subheadline : Font.body).weight(isUnread ? .semibold : .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(compact ? 2 : 2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    if let when = item.relativeTime {
                        Text(when)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.textMuted)
                            .lineLimit(1)
                    }
                }
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(compact ? 2 : 3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if isUnread {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isUnread ? AppColors.primaryContainer.opacity(0.45) : Color.clear)
    }

    private var typeIcon: some View {
        let meta = NotificationTypeStyle.resolve(item.type)
        return ZStack {
            Circle()
                .fill(isUnread ? meta.fill : AppColors.hairline.opacity(0.65))
                .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
            Image(systemName: meta.symbol)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(isUnread ? meta.tint : AppColors.textMuted)
        }
        .accessibilityHidden(true)
    }
}

private struct NotificationTypeStyle {
    let symbol: String
    let tint: Color
    let fill: Color

    static func resolve(_ type: String?) -> NotificationTypeStyle {
        switch type?.uppercased() {
        case "EVENT":
            return .init(symbol: "calendar", tint: AppColors.accentText, fill: AppColors.primaryContainer)
        case "HOURS":
            return .init(symbol: "clock.fill", tint: AppColors.amber, fill: AppColors.amberContainer)
        case "TASK":
            return .init(
                symbol: "checklist",
                tint: Color(uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.45, green: 0.75, blue: 0.98, alpha: 1)
                        : UIColor(red: 0.01, green: 0.41, blue: 0.63, alpha: 1)
                }),
                fill: Color(uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.06, green: 0.16, blue: 0.26, alpha: 1)
                        : UIColor(red: 0.88, green: 0.95, blue: 1, alpha: 1)
                })
            )
        case "BADGE":
            return .init(symbol: "medal.fill", tint: AppColors.amber, fill: AppColors.amberContainer)
        default:
            return .init(symbol: "bell.fill", tint: AppColors.accentText, fill: AppColors.primaryContainer)
        }
    }
}

private extension ApiNotification {
    func markedRead() -> ApiNotification {
        ApiNotification(copying: self, read: true)
    }

    var relativeTime: String? {
        guard let createdAt, let date = Self.parseDate(createdAt) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func parseDate(_ raw: String) -> Date? {
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFractional.date(from: raw) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }
}
