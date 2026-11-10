import SwiftUI

struct EventsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.duoMode) private var duoMode
    @Environment(\.duoCanvasSize) private var canvasSize
    /// When false, parent already provides NavigationStack (Duo detail).
    var embedsNavigation: Bool = true
    @State private var events: [ApiEvent] = []
    @State private var error: String?
    @State private var loading = false
    @State private var selected: ApiEvent?
    @State private var selectedId: String?
    @State private var showCreate = false
    @State private var createToast: String?

    private var isCover: Bool {
        DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height)
    }

    private var sheetDetents: Set<PresentationDetent> {
        isCover ? [.fraction(0.88), .large] : [.medium, .large]
    }

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack { root }
            } else {
                root
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var root: some View {
        if duoMode.usesSplitShell {
            duoInlineBody
        } else {
            compactBody
        }
    }

    // MARK: Compact — list + sheet (Pro Max / folded Duo)

    private var compactBody: some View {
        eventList(useSelectionList: false)
            .background(CGScreenBackground())
            .navigationTitle("Events")
            .modifier(EventsCreateToolbar(canCreate: authStore.session?.canCreateEvents == true) {
                showCreate = true
            })
            .refreshable { await load() }
            .sheet(item: $selected) { event in
                NavigationStack {
                    EventDetailView(event: event, showsDismiss: true) {
                        await load()
                    }
                    .environmentObject(authStore)
                }
                .presentationDetents(sheetDetents)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreate) {
                CreateEventSheet { name in
                    createToast = "“\(name)” published."
                    Task { await load() }
                }
                .environmentObject(authStore)
                .presentationDetents(sheetDetents)
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .top) { createToastBanner }
    }

    // MARK: Duo — inline list | detail (fixed widths; no nested GeometryReaders)

    private var duoInlineBody: some View {
        HStack(spacing: 0) {
            eventList(useSelectionList: true)
                .frame(width: duoMode.eventsListWidth)
                .background(AppColors.canvas)

            Divider().overlay(AppColors.hairline)

            Group {
                if let event = events.first(where: { $0.id == selectedId }) {
                    EventDetailView(event: event, showsDismiss: false) {
                        await load()
                        if let fresh = events.first(where: { $0.id == event.id }) {
                            selectedId = fresh.id
                        }
                    }
                    .environmentObject(authStore)
                    .id(event.id)
                } else {
                    ContentUnavailableView(
                        "Select an event",
                        systemImage: "calendar",
                        description: Text("Pick an event from the list to register or review details.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CGScreenBackground())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CGScreenBackground())
        .navigationTitle("Events")
        .modifier(EventsCreateToolbar(canCreate: authStore.session?.canCreateEvents == true) {
            showCreate = true
        })
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            CreateEventSheet { name in
                createToast = "“\(name)” published."
                Task { await load() }
            }
            .environmentObject(authStore)
            .presentationDetents(sheetDetents)
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) { createToastBanner }
        .onChange(of: events.count) { _, _ in
            reconcileSelection()
        }
        .onAppear { reconcileSelection() }
    }

    @ViewBuilder
    private var createToastBanner: some View {
        if let createToast {
            CGBanner(kind: .success, text: createToast)
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        await MainActor.run { self.createToast = nil }
                    }
                }
        }
    }

    @ViewBuilder
    private func eventList(useSelectionList: Bool) -> some View {
        Group {
            if loading && events.isEmpty {
                ProgressView("Loading events…")
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, events.isEmpty {
                CGEmptyState(title: "Couldn’t load events", systemImage: "exclamationmark.triangle.fill", message: error)
            } else if events.isEmpty {
                CGEmptyState(
                    title: "No upcoming events",
                    systemImage: "calendar",
                    message: "When your organization publishes events, they appear here."
                )
            } else if useSelectionList {
                List(events, selection: $selectedId) { event in
                    EventListRow(event: event)
                        .tag(event.id)
                        .listRowBackground(AppColors.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(CGScreenBackground())
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(events) { event in
                            Button {
                                selected = event
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, duoMode.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, duoMode.chatClearance)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .background(CGScreenBackground())
            }
        }
    }

    private func reconcileSelection() {
        let ids = events.map(\.id)
        if let selectedId, !ids.contains(selectedId) {
            self.selectedId = ids.first
        } else if selectedId == nil {
            selectedId = ids.first
        }
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = events.isEmpty
        error = nil
        do {
            events = try await APIClient.shared.upcomingEvents(token: token)
            reconcileSelection()
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }
}

struct EventListRow: View {
    let event: ApiEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.name ?? "Untitled event")
                .font(CGTypography.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
            if let date = event.date {
                Text(date)
                    .font(CGTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            if let reg = event.myRegistrationStatus, !reg.isEmpty {
                Text(reg.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(CGTypography.sans(12, weight: .bold))
                    .foregroundStyle(AppColors.accentText)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventRow: View {
    let event: ApiEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(event.name ?? "Untitled event")
                    .font(CGTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let status = event.status, !status.isEmpty {
                    Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(CGTypography.sans(12, weight: .bold))
                        .foregroundStyle(AppColors.onPrimaryContainer)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primaryContainer, in: Capsule())
                }
            }

            if let venue = event.venue, !venue.isEmpty {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 14) {
                if let date = event.date {
                    Label(date, systemImage: "calendar")
                }
                if let time = event.startTime {
                    Label(Self.shortTime(time), systemImage: "clock")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.textMuted)

            if let reg = event.myRegistrationStatus, !reg.isEmpty {
                Text(reg.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }

    static func shortTime(_ value: String) -> String {
        let parts = value.split(separator: ":")
        if parts.count >= 2 { return "\(parts[0]):\(parts[1])" }
        return value
    }
}

struct EventDetailView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoMode) private var duoMode
    @State var event: ApiEvent
    var showsDismiss: Bool = true
    var onChanged: () async -> Void

    @State private var busy = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.name ?? "Event")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)

                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }

                CGSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        if let date = event.date {
                            Label(date, systemImage: "calendar")
                        }
                        if let start = event.startTime {
                            Label(
                                "\(EventRow.shortTime(start))\(event.endTime.map { " – \(EventRow.shortTime($0))" } ?? "")",
                                systemImage: "clock"
                            )
                        }
                        if let venue = event.venue, !venue.isEmpty {
                            Label(venue, systemImage: "mappin.and.ellipse")
                        }
                        if let capacity = event.capacity {
                            Label(
                                "\(event.registeredCount ?? 0) / \(capacity) registered",
                                systemImage: "person.3.fill"
                            )
                        }
                        if let reg = event.myRegistrationStatus {
                            Label(
                                reg.replacingOccurrences(of: "_", with: " ").capitalized,
                                systemImage: "checkmark.seal.fill"
                            )
                            .foregroundStyle(AppColors.accentText)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }

                if let message {
                    CGBanner(kind: isError ? .error : .success, text: message)
                }

                if event.isRegistered {
                    CGPrimaryButton(title: "Cancel registration", busy: busy, destructive: true) {
                        Task { await cancel() }
                    }
                } else {
                    CGPrimaryButton(title: "Register", busy: busy) {
                        Task { await register() }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, showsDismiss ? 8 : duoMode.chatClearance * 0.4)
        }
        .scrollIndicators(.hidden)
        .background(CGScreenBackground())
        .modifier(EventDetailNavChrome(showsDismiss: showsDismiss, dismiss: { dismiss() }))
        .task { await refresh() }
    }

    private func refresh() async {
        guard let token = authStore.session?.accessToken else { return }
        if let fresh = try? await APIClient.shared.event(id: event.id, token: token) {
            event = fresh
        }
    }

    private func register() async {
        guard let token = authStore.session?.accessToken else { return }
        busy = true
        message = nil
        do {
            let reg = try await APIClient.shared.register(eventId: event.id, token: token)
            message = "Registered (\((reg.status ?? "CONFIRMED").replacingOccurrences(of: "_", with: " ")))"
            isError = false
            await refresh()
            await onChanged()
        } catch {
            message = authStore.friendlyMessage(for: error)
            isError = true
        }
        busy = false
    }

    private func cancel() async {
        guard let token = authStore.session?.accessToken else { return }
        busy = true
        message = nil
        do {
            try await APIClient.shared.cancelRegistration(eventId: event.id, token: token)
            message = "Registration cancelled."
            isError = false
            await refresh()
            await onChanged()
        } catch {
            message = authStore.friendlyMessage(for: error)
            isError = true
        }
        busy = false
    }
}

/// Sheet presentations own the nav title; Duo inline detail keeps the parent "Events" title.
private struct EventDetailNavChrome: ViewModifier {
    let showsDismiss: Bool
    let dismiss: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if showsDismiss {
            content
                .navigationTitle("Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: dismiss)
                    }
                }
        } else {
            content
        }
    }
}

/// Avoids empty trailing `Extra` slots when the user can't create events (Duo 0×0 bar buttons).
private struct EventsCreateToolbar: ViewModifier {
    let canCreate: Bool
    let onCreate: () -> Void

    func body(content: Content) -> some View {
        if canCreate {
            content.commonGroundToolbar {
                Button(action: onCreate) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.primary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .accessibilityLabel("Create event")
            }
        } else {
            content.commonGroundToolbar()
        }
    }
}
