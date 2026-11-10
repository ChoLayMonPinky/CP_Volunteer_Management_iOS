import SwiftUI

/// Toolbar / top-bar entry — no floating bubble over content.
struct AssistantAskButton: View {
    @EnvironmentObject private var navigation: NavigationStore

    var body: some View {
        Button {
            navigation.openAssistant()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.accentText)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Ask assistant")
        // Do NOT use `.buttonStyle(.plain)` in toolbars — UIKit then lays out 0×0
        // bar buttons and floods Auto Layout constraint errors on Duo cover.
    }
}

/// Shared notifications control — opens the inbox sheet from any screen.
struct NotificationsToolbarButton: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore

    var body: some View {
        Button {
            navigation.openNotifications()
        } label: {
            bellLabel
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(
            navigation.unreadNotifications > 0
                ? "Notifications, \(navigation.unreadNotifications) unread"
                : "Notifications"
        )
        // Debounced — every tab used to fire this and hammer the API + main actor.
        .task(id: authStore.session?.accessToken) {
            await refreshUnreadIfNeeded()
        }
    }

    private var bellLabel: some View {
        Image(systemName: navigation.unreadNotifications > 0 ? "bell.badge.fill" : "bell.fill")
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                navigation.unreadNotifications > 0 ? AppColors.danger : AppColors.accentText,
                AppColors.accentText
            )
    }

    private func refreshUnreadIfNeeded() async {
        guard navigation.shouldRefreshUnread() else { return }
        navigation.markUnreadFetched()
        guard let token = authStore.session?.accessToken else { return }
        if let page = try? await APIClient.shared.myNotifications(token: token, limit: 20) {
            navigation.setUnreadNotifications(page.unreadCount ?? 0)
        }
    }
}

private let assistantWelcome =
    "Hi — I’m your CommonGround assistant. Ask about your hours, upcoming events, tasks, or how to use the app."

private let assistantSuggestions = [
    "How many hours do I have?",
    "What’s my next event?",
    "Any open tasks?",
]

/// Full-screen / sheet chat — presented from the shell, not a floating FAB.
struct AssistantChatSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var welcomeId = UUID()
    @State private var messages: [ChatMessageDTO] = []
    @State private var error: String?
    @State private var sending = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { msg in
                                bubble(msg)
                                    .id(msg.id)
                            }

                            if showSuggestions {
                                suggestionChips
                            }

                            if sending {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(AppColors.primary)
                                    Text("Thinking…")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .id("thinking")
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                    .background(AppColors.canvas)
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: sending) { _, _ in
                        scrollToBottom(proxy)
                    }
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.amber)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.amberContainer)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask about hours, events…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .padding(11)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppColors.hairline, lineWidth: 1)
                        )
                        .onSubmit {
                            Task { await send() }
                        }

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                canSend ? AppColors.primary : Color.gray.opacity(0.45),
                                in: Circle()
                            )
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Send")
                }
                .padding(12)
                .background(AppColors.surface)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.accentText)
                            Text("Assistant")
                                .font(.headline)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        Text("Hours · events · tasks")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        navigation.closeAssistant()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if messages.isEmpty {
                    welcomeId = UUID()
                    messages = [
                        ChatMessageDTO(id: welcomeId, role: "assistant", content: assistantWelcome)
                    ]
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    inputFocused = true
                }
            }
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
    }

    private var showSuggestions: Bool {
        !sending && messages.count <= 1 && messages.allSatisfy { $0.role == "assistant" }
    }

    private var suggestionChips: some View {
        FlowSuggestionLayout(prompts: assistantSuggestions) { prompt in
            Task { await send(prompt) }
        }
    }

    @ViewBuilder
    private func bubble(_ msg: ChatMessageDTO) -> some View {
        let isUser = msg.role == "user"
        HStack {
            if isUser { Spacer(minLength: 36) }
            Text(msg.content)
                .font(.subheadline)
                .foregroundStyle(isUser ? Color.white : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    if isUser {
                        AppColors.heroGradient
                    } else {
                        AppColors.surface
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isUser ? Color.clear : AppColors.hairline, lineWidth: 1)
                )
            if !isUser { Spacer(minLength: 36) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You" : "Assistant")
        .accessibilityValue(msg.content)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.18)) {
            if sending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    private func send(_ preset: String? = nil) async {
        guard let token = authStore.session?.accessToken else { return }
        let text = (preset ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }

        draft = ""
        error = nil
        messages.append(ChatMessageDTO(role: "user", content: text))
        sending = true
        defer { sending = false }

        do {
            // Exclude welcome + the user turn we just appended (sent as `message`).
            let history = messages
                .filter { $0.id != welcomeId }
                .dropLast()
                .suffix(12)
                .map { ChatMessageDTO(role: $0.role, content: $0.content) }
            let response = try await APIClient.shared.chat(
                message: text,
                history: Array(history),
                token: token
            )
            messages.append(ChatMessageDTO(role: "assistant", content: response.reply))
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                if messages.last?.role == "user" {
                    messages.removeLast()
                }
                draft = text
                self.error = authStore.friendlyMessage(for: error)
                return
            }
            self.error = authStore.friendlyMessage(for: error)
            messages.append(
                ChatMessageDTO(
                    role: "assistant",
                    content: "Sorry — I couldn't answer that just now. Please try again in a moment."
                )
            )
        }
    }
}

/// Simple wrapping chip row without a heavy layout dependency.
private struct FlowSuggestionLayout: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(prompts, id: \.self) { prompt in
                Button {
                    onSelect(prompt)
                } label: {
                    Text(prompt)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(AppColors.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// Kept name for any leftover references; prefer `AssistantAskButton` + sheet.
typealias GeminiChatOverlay = AssistantAskButton

/// Ask + notifications on every primary screen.
struct CommonGroundToolbarModifier: ViewModifier {
    @Environment(\.duoCanvasSize) private var canvasSize

    func body(content: Content) -> some View {
        let isCover = DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height)
        content.toolbar {
            // One ToolbarItem (not Group) — stacking multiple trailing items with
            // Events/Hours “+” was zeroing Encapsulated-Layout width/height on Duo.
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: isCover ? 10 : 14) {
                    AssistantAskButton()
                    NotificationsToolbarButton()
                }
                .fixedSize()
            }
        }
    }
}

extension View {
    /// Shared Ask + notifications chrome for every screen.
    func commonGroundToolbar() -> some View {
        modifier(CommonGroundToolbarModifier())
    }

    /// Extra trailing action (e.g. Create event / Log hours) without a second `.toolbar`
    /// that fights the shared Ask + bell buttons.
    func commonGroundToolbar<Extra: View>(@ViewBuilder extraTrailing: () -> Extra) -> some View {
        modifier(CommonGroundToolbarWithExtraModifier(extra: extraTrailing()))
    }

    /// Backward-compatible alias.
    func assistantToolbar() -> some View {
        commonGroundToolbar()
    }
}

private struct CommonGroundToolbarWithExtraModifier<Extra: View>: ViewModifier {
    @Environment(\.duoCanvasSize) private var canvasSize
    let extra: Extra

    func body(content: Content) -> some View {
        let isCover = DuoLayout.isCoverDisplay(width: canvasSize.width, height: canvasSize.height)
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: isCover ? 10 : 14) {
                    extra
                    AssistantAskButton()
                    NotificationsToolbarButton()
                }
                .fixedSize()
            }
        }
    }
}
