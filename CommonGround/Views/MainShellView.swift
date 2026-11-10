import SwiftUI

/// Root post-login shell: compact tabs on phone, Duo split on unfolded / iPad / wide.
struct MainShellView: View {
    @EnvironmentObject private var navigation: NavigationStore

    var body: some View {
        DuoModeReader { mode, size in
            let isCover = DuoLayout.isCoverDisplay(width: size.width, height: size.height)
            Group {
                if mode.usesSplitShell {
                    DuoSplitShell()
                } else {
                    CompactTabShell()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.canvas.ignoresSafeArea())
            .sheet(isPresented: $navigation.showNotifications) {
                NotificationsInboxSheet()
                    .presentationDetents(isCover ? [.fraction(0.88), .large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .environment(\.duoCanvasSize, size)
                    .environment(\.duoMode, mode)
            }
            .sheet(isPresented: $navigation.showAssistant) {
                AssistantChatSheet()
                    .presentationDetents(isCover ? [.fraction(0.88), .large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .environment(\.duoCanvasSize, size)
                    .environment(\.duoMode, mode)
            }
        }
    }
}

// MARK: - Compact (folded / iPhone / Pro Max portrait)

private struct CompactTabShell: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.duoCanvasSize) private var canvasSize

    private var tabs: [AppSection] {
        AppSection.primaryTabs(for: authStore.session)
    }

    var body: some View {
        TabView(selection: tabBinding) {
            ForEach(tabs) { section in
                tabRoot(for: section)
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
            }
        }
        .tint(AppColors.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(AdaptiveTabBarStyle(forceBottomTabs: true))
        .background(AppColors.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func tabRoot(for section: AppSection) -> some View {
        switch section {
        case .home:
            HomeView()
        case .events:
            EventsView()
        case .hours:
            HoursView()
        case .tasks:
            TasksView()
        case .profile:
            ProfileView()
        case .checkIn:
            NavigationStack { CheckInView() }
        case .attendance:
            NavigationStack { AttendanceView() }
        default:
            HomeView()
        }
    }

    private var tabBinding: Binding<AppSection> {
        Binding(
            get: {
                tabs.contains(navigation.section) ? navigation.section : (tabs.first ?? .home)
            },
            set: { navigation.open($0) }
        )
    }
}

/// Sidebar rail only on true unfolded / wide shells — never on Duo outer cover.
private struct AdaptiveTabBarStyle: ViewModifier {
    var forceBottomTabs: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !forceBottomTabs {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}

// MARK: - Duo / expansive split

private struct DuoSplitShell: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.duoMode) private var duoMode

    private var primary: [AppSection] {
        AppSection.primaryTabs(for: authStore.session)
    }

    private var more: [AppSection] {
        AppSection.moreSections(for: authStore.session)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $navigation.columnVisibility) {
            List(selection: sectionBinding) {
                Section("Workspace") {
                    ForEach(primary) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                Section("More") {
                    ForEach(more) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppColors.canvas)
            .navigationTitle("CommonGround")
            .navigationSplitViewColumnWidth(
                min: 200,
                ideal: duoMode.sidebarWidth,
                max: 300
            )
        } detail: {
            DuoDetailHost()
                .background(CGScreenBackground())
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppColors.primary)
    }

    private var sectionBinding: Binding<AppSection?> {
        Binding(
            get: { navigation.section },
            set: { if let value = $0 { navigation.open(value) } }
        )
    }
}

private struct DuoDetailHost: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore

    var body: some View {
        NavigationStack {
            detail(for: navigation.section)
                .transaction { $0.animation = nil }
                .id(navigation.section)
        }
    }

    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        switch section {
        case .home:
            HomeView(embedsNavigation: false)
        case .events:
            EventsView(embedsNavigation: false)
        case .hours:
            HoursView(embedsNavigation: false)
        case .tasks:
            TasksView(embedsNavigation: false)
        case .profile:
            ProfileView(embedsNavigation: false)
        case .checkIn:
            CheckInView()
        case .badges:
            BadgesView()
        case .notifications:
            HomeView(embedsNavigation: false)
                .task { navigation.openNotifications() }
        case .letters:
            LettersView()
        case .myActivities:
            MyActivitiesView()
        case .attendance:
            AttendanceView()
        }
    }
}
