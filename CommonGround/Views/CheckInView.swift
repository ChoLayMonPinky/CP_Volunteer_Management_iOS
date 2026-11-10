import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject private var offline = OfflineCheckInStore.shared
    @State private var events: [ApiEvent] = []
    @State private var selectedEventId: String?
    @State private var eventCode = ""
    @State private var loading = false
    @State private var submitting = false
    @State private var error: String?
    @State private var success: String?
    @State private var queuedMessage: String?
    @State private var showScanner = false

    private var checkInCandidates: [ApiEvent] {
        let preferred = events.filter { $0.canSelfCheckIn || ($0.myRegistrationStatus ?? "").uppercased() == "CHECKED_IN" }
        return preferred.isEmpty ? events.filter(\.isRegistered) : preferred
    }

    private var selectedEvent: ApiEvent? {
        events.first(where: { $0.id == selectedEventId })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CGSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Event check-in", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(AppColors.accentText)
                        Text("Scan the leader’s QR or enter the short code. Works offline — we’ll sync when you’re back online.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                if !offline.pending.isEmpty {
                    CGSurface {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.slash")
                                .foregroundStyle(AppColors.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    offline.pending.count == 1
                                        ? "1 check-in waiting to sync"
                                        : "\(offline.pending.count) check-ins waiting to sync"
                                )
                                .font(.subheadline.weight(.semibold))
                                Text(offline.flushing ? "Syncing now…" : "We’ll send them when you’re back online.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            Spacer()
                            Button(offline.flushing ? "…" : "Sync") {
                                offline.requestFlush(token: authStore.session?.accessToken)
                            }
                            .font(.caption.weight(.bold))
                            .disabled(offline.flushing)
                        }
                    }
                }

                if loading && events.isEmpty {
                    ProgressView("Loading events…")
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    CGSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Event")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.textMuted)

                            if checkInCandidates.isEmpty {
                                Text("No confirmed upcoming events found. Register first, then check in once confirmed.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                Picker("Event", selection: $selectedEventId) {
                                    Text("Select an event").tag(Optional<String>.none)
                                    ForEach(checkInCandidates) { event in
                                        Text(eventLabel(event)).tag(Optional(event.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppColors.accentText)
                            }
                        }
                    }

                    if let status = selectedEvent?.myRegistrationStatus?.uppercased(), status == "CHECKED_IN" {
                        CGBanner(kind: .success, text: "You’re already checked in for this event.")
                    } else if selectedEvent?.canSelfCheckIn == true {
                        CGPrimaryButton(title: "Scan QR code", busy: false, enabled: !submitting) {
                            showScanner = true
                        }

                        CGSurface {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Or enter code")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.textMuted)
                                TextField("e.g. GR1234", text: $eventCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .font(.title3.weight(.semibold).monospaced())
                                    .cgField()
                            }
                        }

                        CGPrimaryButton(
                            title: "Check in with code",
                            busy: submitting,
                            enabled: selectedEventId != nil
                                && !eventCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            Task { await submit(code: eventCode) }
                        }
                    }
                }

                if let error { CGBanner(kind: .error, text: error) }
                if let queuedMessage { CGBanner(kind: .info, text: queuedMessage) }
                if let success { CGBanner(kind: .success, text: success) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(CGScreenBackground())
        .navigationTitle("Check-in")
        .commonGroundToolbar()
        .task {
            await loadEvents()
            offline.requestFlush(token: authStore.session?.accessToken)
        }
        .refreshable {
            await loadEvents()
            offline.requestFlush(token: authStore.session?.accessToken)
        }
        .sheet(isPresented: $showScanner) {
            QrScannerSheet { code in
                eventCode = code
                Task { await submit(code: code) }
            }
        }
    }

    private func eventLabel(_ event: ApiEvent) -> String {
        let name = event.name ?? "Event"
        if let date = event.date {
            return "\(name) · \(date)"
        }
        return name
    }

    private func loadEvents() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = events.isEmpty
        error = nil
        do {
            events = try await APIClient.shared.upcomingEvents(token: token)
            if selectedEventId == nil {
                selectedEventId = checkInCandidates.first?.id
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }

    private func submit(code raw: String) async {
        guard let token = authStore.session?.accessToken,
              let eventId = selectedEventId
        else { return }

        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        submitting = true
        error = nil
        success = nil
        queuedMessage = nil
        defer { submitting = false }

        let eventName = selectedEvent?.name
        // If we already know the path is down, queue immediately — don't wait on
        // URLSession waitsForConnectivity / long timeouts.
        if !offline.pathSatisfied {
            offline.enqueue(eventId: eventId, eventName: eventName, code: code)
            queuedMessage = "You’re offline — check-in saved and will sync when you’re back online."
            eventCode = ""
            return
        }

        do {
            let result = try await APIClient.shared.selfCheckIn(
                eventId: eventId,
                code: code,
                token: token
            )
            offline.remove(eventId: eventId)
            let name = result.eventName ?? eventName ?? "event"
            let status = result.status ?? "CHECKED_IN"
            success = "Checked in to \(name) (\(status.replacingOccurrences(of: "_", with: " ").capitalized))."
            eventCode = ""
            await loadEvents()
        } catch {
            if Self.isTransientFailure(error) {
                offline.enqueue(eventId: eventId, eventName: eventName, code: code)
                queuedMessage = "You’re offline — check-in saved and will sync when you’re back online."
                eventCode = ""
            } else {
                self.error = authStore.friendlyMessage(for: error)
            }
        }
    }

    private static func isTransientFailure(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost,
                 .cannotConnectToHost, .cannotFindHost, .dataNotAllowed, .dnsLookupFailed:
                return true
            default:
                return true // path monitor / waitsForConnectivity failures still queue
            }
        }
        if let api = error as? APIError {
            switch api {
            case .http(let code, let body):
                if code >= 500 { return true }
                let msg = (body ?? "").lowercased()
                return msg.contains("network") || msg.contains("timeout") || msg.contains("connection")
            case .message(let text):
                let msg = text.lowercased()
                return msg.contains("network") || msg.contains("internet") || msg.contains("reach")
                    || msg.contains("timed") || msg.contains("took too long") || msg.contains("connection")
                    || msg.contains("waking up")
            default:
                return false
            }
        }
        return false
    }
}
