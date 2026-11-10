import SwiftUI

struct MyActivitiesView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.duoMode) private var duoMode
    @State private var items: [ActivityRow] = []
    @State private var hoursTotal: Double = 0
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    metric(title: "Hours", value: String(format: "%.1f", hoursTotal))
                    metric(title: "Active", value: "\(items.filter { $0.kind == .upcoming }.count)")
                    metric(title: "Done", value: "\(items.filter { $0.kind == .attended }.count)")
                }

                Text("Your registrations")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if let error {
                    CGBanner(kind: .error, text: error)
                }

                if loading && items.isEmpty {
                    ProgressView("Loading…")
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if items.isEmpty {
                    CGEmptyState(
                        title: "No registrations yet",
                        systemImage: "calendar.badge.plus",
                        message: "Browse Events to join an opportunity."
                    )
                } else {
                    ForEach(items) { item in
                        CGSurface {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(AppColors.accentText)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Text(item.statusLabel)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.onPrimaryContainer)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.primaryContainer, in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, duoMode.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, duoMode.chatClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(CGScreenBackground())
        .navigationTitle("My Activities")
        .commonGroundToolbar()
        .task { await load() }
        .refreshable { await load() }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textMuted)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppColors.accentText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = items.isEmpty
        error = nil
        defer { loading = false }

        if let summary = try? await APIClient.shared.mySummary(token: token) {
            hoursTotal = summary.totalHours ?? 0
        }

        do {
            let regs = try await APIClient.shared.myRegistrations(token: token)
            items = regs.map { reg in
                let status = (reg.status ?? "").uppercased()
                let done = ["COMPLETED", "NO_SHOW", "CANCELLED"].contains(status)
                return ActivityRow(
                    id: reg.id,
                    kind: done ? .attended : .upcoming,
                    title: reg.eventName ?? "Event",
                    detail: [reg.eventDate, reg.startTime].compactMap { $0 }.joined(separator: " · "),
                    statusLabel: status.replacingOccurrences(of: "_", with: " ").capitalized,
                    systemImage: done ? "checkmark.circle.fill" : "calendar"
                )
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
    }
}

private struct ActivityRow: Identifiable {
    enum Kind { case upcoming, attended }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let statusLabel: String
    let systemImage: String
}
