import SwiftUI

struct HoursView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.duoMode) private var duoMode
    @Environment(\.duoCanvasSize) private var canvasSize
    var embedsNavigation: Bool = true
    @State private var logs: [ApiHourLog] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showLogSheet = false

    private var isCover: Bool {
        DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height)
    }

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack { hoursContent }
            } else {
                hoursContent
            }
        }
    }

    private var hoursContent: some View {
        Group {
            if loading && logs.isEmpty {
                ProgressView("Loading hours…")
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, logs.isEmpty {
                CGEmptyState(title: "Couldn’t load hours", systemImage: "exclamationmark.triangle.fill", message: error)
            } else if logs.isEmpty {
                CGEmptyState(
                    title: "No hour logs yet",
                    systemImage: "clock",
                    message: "Log volunteer hours after events — they sync with the web app."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(logs) { log in
                            HourRow(log: log)
                        }
                    }
                    .padding(.horizontal, duoMode.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, duoMode.chatClearance)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(CGScreenBackground())
        .navigationTitle("Hours")
        .commonGroundToolbar {
            Button {
                showLogSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppColors.primary)
                    .frame(minWidth: 28, minHeight: 28)
            }
            .accessibilityLabel("Log hours")
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showLogSheet) {
            LogHoursSheet {
                await load()
            }
            .environmentObject(authStore)
            .presentationDetents(isCover ? [.fraction(0.88), .large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = logs.isEmpty
        error = nil
        do {
            logs = try await APIClient.shared.myHours(token: token)
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }
}

private struct HourRow: View {
    let log: ApiHourLog

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(log.eventName ?? "Manual hours")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if let date = log.workDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
                if let description = log.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.2fh", log.hours ?? 0))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.accentText)
                Text((log.status ?? "—").capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.onPrimaryContainer)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.primaryContainer, in: Capsule())
            }
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }
}

private struct LogHoursSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    var onSaved: () async -> Void

    @State private var date = Date()
    @State private var hours = "2"
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Work date", selection: $date, displayedComponents: .date)
                TextField("Hours", text: $hours)
                    .keyboardType(.decimalPad)
                TextField("Description (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                if let error {
                    Text(error).foregroundStyle(AppColors.danger).font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CGScreenBackground())
            .navigationTitle("Log hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(busy)
                }
            }
        }
    }

    private func submit() async {
        guard let token = authStore.session?.accessToken else { return }
        guard let value = Double(hours.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            error = "Enter a valid hours amount."
            return
        }
        busy = true
        error = nil
        do {
            _ = try await APIClient.shared.submitHours(
                HourLogRequest(
                    workDate: formatter.string(from: date),
                    hours: value,
                    description: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                    eventId: nil
                ),
                token: token
            )
            await onSaved()
            dismiss()
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        busy = false
    }
}
