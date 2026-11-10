import SwiftUI
import UIKit

/// Letters & certificates — Leaders and Volunteers can view and download/share.
struct LettersView: View {
    @Environment(\.duoMode) private var duoMode
    @EnvironmentObject private var authStore: AuthStore
    @State private var hours: [ApiHourLog] = []
    @State private var summary: MySummary?
    @State private var loading = false
    @State private var error: String?
    @State private var toast: String?
    @State private var sharePayload: SharePayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CGSurface {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Your documents", systemImage: "doc.text.fill")
                            .font(.headline)
                            .foregroundStyle(AppColors.accentText)
                        Text("Download your service hours transcript, appreciation letter, and related certificates. Available for Volunteers and Leaders.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                if let error {
                    CGBanner(kind: .error, text: error)
                }
                if let toast {
                    CGBanner(kind: .success, text: toast)
                }

                if loading && hours.isEmpty {
                    ProgressView("Loading documents…")
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                }

                letterCard(
                    title: "Service hours transcript",
                    subtitle: "Verified summary of logged hours for school / employer.",
                    systemImage: "list.bullet.rectangle.fill",
                    ready: true
                ) {
                    share(
                        title: "Service hours transcript",
                        body: LetterDocumentBuilder.serviceTranscript(
                            name: authStore.session?.fullName ?? "Volunteer",
                            email: authStore.session?.email ?? "",
                            role: authStore.session?.roleLabel ?? "Volunteer",
                            hours: hours,
                            totalHours: summary?.totalHours ?? hours.reduce(0) { $0 + ($1.hours ?? 0) }
                        )
                    )
                }

                letterCard(
                    title: "Appreciation letter",
                    subtitle: "Thank-you letter recognising your volunteer service with CommonGround.",
                    systemImage: "rosette",
                    ready: true
                ) {
                    share(
                        title: "Appreciation letter",
                        body: LetterDocumentBuilder.appreciationLetter(
                            name: authStore.session?.fullName ?? "Volunteer",
                            role: authStore.session?.roleLabel ?? "Volunteer",
                            totalHours: summary?.totalHours ?? hours.reduce(0) { $0 + ($1.hours ?? 0) }
                        )
                    )
                }

                let total = summary?.totalHours ?? hours.reduce(0) { $0 + ($1.hours ?? 0) }
                let eligible = total >= 100
                letterCard(
                    title: "100h recommendation letter",
                    subtitle: eligible
                        ? "Eligible — download a recommendation draft based on your verified hours."
                        : "Unlocks after 100 verified hours (currently \(String(format: "%.1f", total))h).",
                    systemImage: "envelope.fill",
                    ready: eligible
                ) {
                    share(
                        title: "Recommendation letter",
                        body: LetterDocumentBuilder.recommendationLetter(
                            name: authStore.session?.fullName ?? "Volunteer",
                            role: authStore.session?.roleLabel ?? "Volunteer",
                            totalHours: total
                        )
                    )
                }
            }
            .padding(.horizontal, duoMode.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, duoMode.chatClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(CGScreenBackground())
        .navigationTitle("Letters")
        .commonGroundToolbar()
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: [payload.fileURL as Any, payload.body])
        }
    }

    private func letterCard(
        title: String,
        subtitle: String,
        systemImage: String,
        ready: Bool,
        action: @escaping () -> Void
    ) -> some View {
        CGSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundStyle(AppColors.accentText)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(ready ? "Ready" : "Locked")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.onPrimaryContainer)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            ready ? AppColors.primaryContainer : AppColors.canvas,
                            in: Capsule()
                        )
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                Button(action: action) {
                    Text(ready ? "Download / Share" : "Not available yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ready ? AppColors.accentText : AppColors.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(!ready)
            }
        }
    }

    private func share(title: String, body: String) {
        let safe = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe).txt")
        do {
            try body.data(using: .utf8)?.write(to: url)
            sharePayload = SharePayload(id: UUID().uuidString, title: title, body: body, fileURL: url)
            toast = "Ready to share “\(title)”."
        } catch {
            toast = "Couldn’t prepare download. Please try again."
        }
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = hours.isEmpty
        error = nil
        defer { loading = false }
        do {
            async let hoursReq = APIClient.shared.myHours(token: token)
            async let summaryReq = APIClient.shared.mySummary(token: token)
            hours = try await hoursReq
            summary = try? await summaryReq
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
    }
}

// MARK: - Document builders

enum LetterDocumentBuilder {
    private static var issuedOn: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }

    static func serviceTranscript(
        name: String,
        email: String,
        role: String,
        hours: [ApiHourLog],
        totalHours: Double
    ) -> String {
        var lines: [String] = [
            "===============================================================",
            "                 COMMONGROUND VOLUNTEER SYSTEM",
            "            OFFICIAL SERVICE OF HOURS TRANSCRIPT",
            "===============================================================",
            "Date of issuance : \(issuedOn)",
            "Volunteer name   : \(name)",
            "Email            : \(email)",
            "Role             : \(role)",
            "Total hours      : \(String(format: "%.1f", totalHours))",
            "",
            "Verified hour logs",
            "---------------------------------------------------------------"
        ]
        if hours.isEmpty {
            lines.append("(No hour logs returned from the server yet.)")
        } else {
            for log in hours {
                let date = log.workDate ?? "—"
                let event = log.eventName ?? "General service"
                let h = String(format: "%.1f", log.hours ?? 0)
                let status = (log.status ?? "logged").replacingOccurrences(of: "_", with: " ")
                lines.append("• \(date)  \(h)h  \(event)  [\(status)]")
                if let note = log.description, !note.isEmpty {
                    lines.append("    \(note)")
                }
            }
        }
        lines.append("")
        lines.append("This transcript summarises volunteer service recorded in CommonGround.")
        lines.append("===============================================================")
        return lines.joined(separator: "\n")
    }

    static func appreciationLetter(name: String, role: String, totalHours: Double) -> String {
        """
        COMMONGROUND
        Letter of Appreciation

        Date: \(issuedOn)

        Dear \(name),

        On behalf of CommonGround organisers, thank you for your dedicated volunteer service \
        as a \(role). Your contribution of \(String(format: "%.1f", totalHours)) verified hours \
        strengthens our community programmes and inspires others to serve.

        We are grateful for your reliability, care, and commitment. Please keep this letter \
        as recognition of your service.

        With appreciation,
        CommonGround Volunteer Management
        """
    }

    static func recommendationLetter(name: String, role: String, totalHours: Double) -> String {
        """
        COMMONGROUND
        Recommendation Letter (100+ hours)

        Date: \(issuedOn)

        To whom it may concern,

        This letter confirms that \(name) has completed \(String(format: "%.1f", totalHours)) \
        verified volunteer hours with CommonGround in the capacity of \(role).

        Their sustained service demonstrates commitment, teamwork, and community leadership. \
        We recommend them for programmes, scholarships, or roles that value civic contribution.

        Sincerely,
        CommonGround Volunteer Management
        """
    }
}

// MARK: - Share sheet

private struct SharePayload: Identifiable {
    let id: String
    let title: String
    let body: String
    let fileURL: URL
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
