import SwiftUI

struct CreateEventSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((String) -> Void)?

    @State private var name = ""
    @State private var date = Date().addingTimeInterval(86_400)
    @State private var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var end = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var venue = ""
    @State private var capacity = "30"
    @State private var department = "Community"
    @State private var notes = ""
    @State private var busy = false
    @State private var error: String?

    private let departments = ["Community", "Education", "Health", "Environment", "Ops"]

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Event name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                    TextField("Venue", text: $venue)
                }
                Section("Capacity & team") {
                    TextField("Volunteer capacity", text: $capacity)
                        .keyboardType(.numberPad)
                    Picker("Category", selection: $department) {
                        ForEach(departments, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Notes") {
                    TextField("Optional details", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(AppColors.danger)
                    }
                }
            }
            .navigationTitle("Create event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Saving…" : "Publish") {
                        Task { await publish() }
                    }
                    .disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func publish() async {
        guard let token = authStore.session?.accessToken else {
            error = "Please sign in again."
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Name is required."
            return
        }
        let cap = Int(capacity.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard cap > 0 else {
            error = "Capacity must be at least 1."
            return
        }
        guard end > start else {
            error = "End time must be after start time."
            return
        }

        busy = true
        error = nil
        defer { busy = false }

        let body = EventCreateRequest(
            name: trimmed,
            description: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            category: department,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            address: nil,
            remote: false,
            meetingLink: nil,
            date: dateFormatter.string(from: date),
            startTime: timeFormatter.string(from: start),
            endTime: timeFormatter.string(from: end),
            capacity: cap,
            status: "OPEN",
            imageUrl: nil
        )

        do {
            let created = try await APIClient.shared.createEvent(body, token: token)
            onCreated?(created.name ?? trimmed)
            dismiss()
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
