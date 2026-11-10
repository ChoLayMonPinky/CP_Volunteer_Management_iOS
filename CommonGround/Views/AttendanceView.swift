import SwiftUI

/// Leader / organiser roll-call — live roster from `/api/events/{id}/registrations`.
struct AttendanceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var events: [ApiEvent] = []
    @State private var selectedEventId: String?
    @State private var roster: [ApiRegistration] = []
    @State private var loadingEvents = false
    @State private var loadingRoster = false
    @State private var busyId: String?
    @State private var error: String?
    @State private var notice: String?

    private var selectedEvent: ApiEvent? {
        events.first(where: { $0.id == selectedEventId })
    }

    private var checkedInCount: Int {
        roster.filter { $0.statusKey == "CHECKED_IN" }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CGSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Attendance", systemImage: "person.3.sequence.fill")
                            .font(.headline)
                            .foregroundStyle(AppColors.accentText)
                        Text("Select an event, then check volunteers in or out on site.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                CGSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Event")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.textMuted)
                        if loadingEvents && events.isEmpty {
                            ProgressView().tint(AppColors.primary)
                        } else if events.isEmpty {
                            Text("No upcoming events.")
                                .foregroundStyle(AppColors.textSecondary)
                        } else {
                            Picker("Event", selection: $selectedEventId) {
                                Text("Select an event").tag(Optional<String>.none)
                                ForEach(events) { event in
                                    Text(event.name ?? "Event").tag(Optional(event.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accentText)
                            .onChange(of: selectedEventId) { _, _ in
                                Task { await loadRoster() }
                            }
                        }
                    }
                }

                if let event = selectedEvent, let code = event.checkInCode, !code.isEmpty {
                    CGSurface {
                        VStack(spacing: 12) {
                            Text("Volunteer check-in QR")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Show this code at the venue — volunteers can scan or type it.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            CheckInQrImage(code: code, size: 180)
                            Text(code)
                                .font(.title2.weight(.bold).monospaced())
                                .foregroundStyle(AppColors.primary)
                            if authStore.session?.canManageAttendance == true {
                                Button("Regenerate code") {
                                    Task { await regenerateCode() }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.primary)
                                .disabled(busyId != nil)
                            }
                        }
                    }
                }

                if selectedEventId != nil {
                    CGSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Roster")
                                    .font(.headline)
                                Spacer()
                                Text("\(checkedInCount)/\(roster.count) in")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.textMuted)
                            }

                            if loadingRoster && roster.isEmpty {
                                ProgressView("Loading roster…").tint(AppColors.primary)
                            } else if roster.isEmpty {
                                Text("No registrations yet.")
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                ForEach(roster) { person in
                                    rosterRow(person)
                                    if person.id != roster.last?.id {
                                        Divider().overlay(AppColors.hairline)
                                    }
                                }
                            }
                        }
                    }
                }

                if let error { CGBanner(kind: .error, text: error) }
                if let notice { CGBanner(kind: .success, text: notice) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(CGScreenBackground())
        .navigationTitle("Attendance")
        .commonGroundToolbar()
        .task { await loadEvents() }
        .refreshable {
            await loadEvents()
            await loadRoster()
        }
    }

    @ViewBuilder
    private func rosterRow(_ person: ApiRegistration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(person.statusKey.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                switch person.statusKey {
                case "CHECKED_IN":
                    actionButton("Check out", kind: .secondary) {
                        await staffAction(.checkOut, person)
                    }
                case "CONFIRMED", "NO_SHOW":
                    actionButton("Check in", kind: .primary) {
                        await staffAction(.checkIn, person)
                    }
                    actionButton("No-show", kind: .secondary) {
                        await staffAction(.noShow, person)
                    }
                case "WAITLIST":
                    Text("Waitlisted — confirm before check-in")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(busyId == person.id ? 0.55 : 1)
    }

    private enum ActionKind { case primary, secondary }

    private func actionButton(_ title: String, kind: ActionKind, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(busyId != nil ? "…" : title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(kind == .primary ? AppColors.primary : AppColors.primaryContainer)
                .foregroundStyle(kind == .primary ? Color.white : AppColors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busyId != nil)
    }

    private enum StaffAction { case checkIn, checkOut, noShow }

    private func loadEvents() async {
        guard let token = authStore.session?.accessToken else { return }
        loadingEvents = events.isEmpty
        error = nil
        do {
            events = try await APIClient.shared.upcomingEvents(token: token)
            if selectedEventId == nil {
                selectedEventId = events.first?.id
            }
            if selectedEventId != nil {
                await loadRoster()
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loadingEvents = false
    }

    private func loadRoster() async {
        guard let token = authStore.session?.accessToken,
              let eventId = selectedEventId
        else {
            roster = []
            return
        }
        loadingRoster = roster.isEmpty
        error = nil
        do {
            roster = try await APIClient.shared.eventRegistrations(eventId: eventId, token: token)
            // Refresh selected event for QR code
            if let fresh = try? await APIClient.shared.event(id: eventId, token: token),
               let idx = events.firstIndex(where: { $0.id == eventId }) {
                events[idx] = fresh
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loadingRoster = false
    }

    private func staffAction(_ action: StaffAction, _ person: ApiRegistration) async {
        guard let token = authStore.session?.accessToken,
              let eventId = selectedEventId
        else { return }
        busyId = person.id
        error = nil
        notice = nil
        defer { busyId = nil }
        do {
            switch action {
            case .checkIn:
                _ = try await APIClient.shared.staffCheckIn(eventId: eventId, registrationId: person.id, token: token)
                notice = "Checked in \(person.displayName)"
            case .checkOut:
                _ = try await APIClient.shared.staffCheckOut(eventId: eventId, registrationId: person.id, token: token)
                notice = "Checked out \(person.displayName)"
            case .noShow:
                _ = try await APIClient.shared.markNoShow(eventId: eventId, registrationId: person.id, token: token)
                notice = "Marked no-show"
            }
            await loadRoster()
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
    }

    private func regenerateCode() async {
        guard let token = authStore.session?.accessToken,
              let eventId = selectedEventId
        else { return }
        busyId = "regen"
        error = nil
        defer { busyId = nil }
        do {
            let fresh = try await APIClient.shared.regenerateCheckInCode(eventId: eventId, token: token)
            if let idx = events.firstIndex(where: { $0.id == eventId }) {
                events[idx] = fresh
            }
            notice = "New code: \(fresh.checkInCode ?? "—")"
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
    }
}
