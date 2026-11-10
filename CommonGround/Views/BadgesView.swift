import SwiftUI
import UIKit

struct BadgesView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.duoMode) private var duoMode
    @State private var summary: ApiBadgeSummary?
    @State private var error: String?
    @State private var loading = false
    @State private var shareItems: [Any]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error { CGBanner(kind: .error, text: error) }

                CGSurface {
                    Text("Volunteers and Leaders can download certificates for earned badges.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if loading && summary == nil {
                    ProgressView("Loading badges…")
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                } else if let summary {
                    CGSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total hours")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textMuted)
                            Text(String(format: "%.1f", summary.totalHours ?? 0))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accentText)
                            if let next = summary.next {
                                ProgressView(value: min(max(next.progress ?? 0, 0), 1))
                                    .tint(AppColors.primary)
                                Text("Next: \(next.title ?? "milestone") at \(next.hours ?? 0)h")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }

                    ForEach(summary.badges ?? []) { badge in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: (badge.earned == true) ? "medal.fill" : "medal")
                                    .font(.title2)
                                    .foregroundStyle((badge.earned == true) ? AppColors.primary : AppColors.textMuted)
                                    .frame(width: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(badge.title ?? "Badge")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("\(badge.hours ?? 0) hours · \((badge.tier ?? "").capitalized)")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                Spacer()
                                Text((badge.earned == true) ? "Earned" : "Locked")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle((badge.earned == true) ? AppColors.accentText : AppColors.textMuted)
                            }
                            if badge.earned == true {
                                Button {
                                    shareBadge(badge)
                                } label: {
                                    Text("Download / Share")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.accentText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppColors.hairline, lineWidth: 1)
                        )
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
        .navigationTitle("Badges")
        .commonGroundToolbar()
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let shareItems {
                BadgeActivityShareSheet(items: shareItems)
            }
        }
    }

    private func shareBadge(_ badge: ApiBadge) {
        let name = authStore.session?.fullName ?? "Volunteer"
        let title = badge.title ?? "Badge"
        let body = """
        COMMONGROUND — BADGE CERTIFICATE
        ================================
        Volunteer : \(name)
        Badge     : \(title)
        Tier      : \((badge.tier ?? "").capitalized)
        Hours     : \(badge.hours ?? 0)

        Status: Earned and recorded in CommonGround.
        """
        let safe = title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Badge_\(safe).txt")
        try? body.data(using: .utf8)?.write(to: url)
        shareItems = [url, body]
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = summary == nil
        error = nil
        do {
            summary = try await APIClient.shared.myBadges(token: token)
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }
}

private struct BadgeActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
