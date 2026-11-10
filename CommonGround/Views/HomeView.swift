import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.duoMode) private var duoMode
    @Environment(\.duoCanvasSize) private var canvasSize
    /// When false, parent already provides NavigationStack (Duo detail).
    var embedsNavigation: Bool = true
    @State private var summary: MySummary?
    @State private var badges: ApiBadgeSummary?
    @State private var error: String?
    @State private var loading = false
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack(path: $path) {
                    homeContent
                        .navigationDestination(for: HomeRoute.self) { route in
                            destination(for: route)
                        }
                }
            } else {
                homeContent
                    .navigationDestination(for: HomeRoute.self) { route in
                        destination(for: route)
                    }
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let error { CGBanner(kind: .error, text: error) }

                if loading && summary == nil {
                    ProgressView("Loading…")
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else if let summary {
                    metricsStrip(summary)

                    if let badges {
                        badgeCard(badges)
                    }

                    quickActions
                }
            }
            .padding(.horizontal, duoMode.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, duoMode.chatClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(CGScreenBackground())
        .navigationTitle("Home")
        .commonGroundToolbar()
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .badges: BadgesView()
        case .checkIn: CheckInView()
        case .letters: LettersView()
        case .myActivities: MyActivitiesView()
        case .attendance: AttendanceView()
        case .hours: HoursView(embedsNavigation: false)
        case .tasks: TasksView(embedsNavigation: false)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CommonGround")
                .font(CGTypography.sans(12, weight: .bold))
                .foregroundStyle(AppColors.accentText)
                .tracking(0.6)

            HStack(alignment: .center, spacing: 8) {
                Text("Hello, \(authStore.session?.firstName ?? "Volunteer")")
                    .font(CGTypography.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                CGRoleBadge(label: authStore.session?.roleLabel ?? "Volunteer")
                Spacer(minLength: 0)
            }

            Text(duoMode.usesSplitShell
                 ? "Use the sidebar to jump between hours, events, and tasks."
                 : "Your hours, events, and tasks in one place.")
                .font(CGTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func metricsStrip(_ summary: MySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("At a glance")
                .font(CGTypography.label)
                .foregroundStyle(AppColors.textMuted)

            HStack(spacing: 0) {
                MetricCell(title: "Hours", value: String(format: "%.1f", summary.totalHours ?? 0))
                metricDivider
                MetricCell(title: "Upcoming", value: "\(summary.upcomingRegistrations ?? 0)")
                metricDivider
                MetricCell(title: "Tasks", value: "\(summary.openTasks ?? 0)")
                metricDivider
                MetricCell(title: "Pending", value: "\(summary.pendingHourLogs ?? 0)")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: 1)
            )
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(AppColors.hairline)
            .frame(width: 1, height: 36)
    }

    private func badgeCard(_ badges: ApiBadgeSummary) -> some View {
        Button {
            openSecondary(.badges)
        } label: {
            CGSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Badge progress", systemImage: "medal.fill")
                            .font(CGTypography.cardTitle)
                            .foregroundStyle(AppColors.accentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    if let current = badges.current {
                        Text(current.title ?? "Current badge")
                            .font(CGTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        Text("Earn your first badge by logging hours.")
                            .font(CGTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let next = badges.next {
                        ProgressView(value: min(max(next.progress ?? 0, 0), 1))
                            .tint(AppColors.primary)
                        Text("Next: \(next.title ?? "milestone") · \(next.hours ?? 0)h")
                            .font(CGTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(CGTypography.label)
                .foregroundStyle(AppColors.textMuted)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: canvasSize.width >= 520 || duoMode != .compact ? 3 : 2
                ),
                spacing: 10
            ) {
                QuickAction(title: "Events", systemImage: "calendar") { openPrimary(.events) }
                QuickAction(title: "Log hours", systemImage: "clock.badge.checkmark") { openPrimary(.hours) }
                QuickAction(title: "My tasks", systemImage: "checklist") { openPrimary(.tasks) }
                QuickAction(title: "My activities", systemImage: "rectangle.stack.person.crop.fill") { openSecondary(.myActivities) }
                QuickAction(title: "Check-in", systemImage: "checkmark.seal.fill") { openSecondary(.checkIn) }
                if authStore.session?.canManageAttendance == true {
                    QuickAction(title: "Attendance", systemImage: "person.3.sequence.fill") { openSecondary(.attendance) }
                }
                QuickAction(title: "Badges", systemImage: "medal.fill") { openSecondary(.badges) }
                QuickAction(title: "Letters", systemImage: "doc.text.fill") { openSecondary(.letters) }
            }
        }
    }

    private func openPrimary(_ section: AppSection) {
        let tabs = AppSection.primaryTabs(for: authStore.session)
        if duoMode.usesSplitShell || tabs.contains(section) {
            navigation.open(section)
            return
        }
        // Compact shell: section isn't a primary tab for this role — push instead.
        openSecondary(section)
    }

    private func openSecondary(_ section: AppSection) {
        if section == .notifications {
            navigation.openNotifications()
            return
        }
        if duoMode.usesSplitShell {
            navigation.open(section)
            return
        }
        switch section {
        case .badges: path.append(HomeRoute.badges)
        case .checkIn: path.append(HomeRoute.checkIn)
        case .letters: path.append(HomeRoute.letters)
        case .myActivities: path.append(HomeRoute.myActivities)
        case .attendance: path.append(HomeRoute.attendance)
        case .hours: path.append(HomeRoute.hours)
        case .tasks: path.append(HomeRoute.tasks)
        default: navigation.open(section)
        }
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = true
        error = nil
        do {
            async let summaryReq = APIClient.shared.mySummary(token: token)
            async let badgesReq = APIClient.shared.myBadges(token: token)
            summary = try await summaryReq
            badges = try? await badgesReq
            if let count = summary?.unreadNotifications {
                navigation.setUnreadNotifications(count)
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }
}

private enum HomeRoute: Hashable {
    case badges, checkIn, letters, myActivities, attendance, hours, tasks
}

private struct MetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(CGTypography.metric)
                .foregroundStyle(AppColors.accentText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(CGTypography.caption)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accentText)
                    .frame(width: 34, height: 34)
                    .background(AppColors.primaryContainer, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(CGTypography.label)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
