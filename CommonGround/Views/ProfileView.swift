import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    @Environment(\.duoMode) private var duoMode
    @EnvironmentObject private var appearanceStore: AppearanceStore
    var embedsNavigation: Bool = true

    @State private var fullName = ""
    @State private var phone = ""
    @State private var isEditingPersonal = false
    @State private var personalToast: String?
    @FocusState private var focusedField: PersonalField?

    private enum PersonalField { case name, phone }

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack { profileContent }
            } else {
                profileContent
            }
        }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                personalInfoBox

                CGSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(CGTypography.label)
                            .foregroundStyle(AppColors.textMuted)

                        Picker("Appearance", selection: $appearanceStore.appearance) {
                            ForEach(AppAppearance.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Optimised for both Light and Dark. System follows your iPhone setting.")
                            .font(CGTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }

                CGSurface(padding: 4) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            MyActivitiesView()
                        } label: {
                            settingsRow(title: "My Activities", systemImage: "rectangle.stack.person.crop.fill")
                        }
                        Divider().overlay(AppColors.hairline).padding(.leading, 40)
                        NavigationLink {
                            CheckInView()
                        } label: {
                            settingsRow(title: "Check-in", systemImage: "checkmark.seal.fill")
                        }
                        if authStore.session?.canManageAttendance == true {
                            Divider().overlay(AppColors.hairline).padding(.leading, 40)
                            NavigationLink {
                                AttendanceView()
                            } label: {
                                settingsRow(title: "Attendance roll-call", systemImage: "person.3.sequence.fill")
                            }
                        }
                        Divider().overlay(AppColors.hairline).padding(.leading, 40)
                        NavigationLink {
                            BadgesView()
                        } label: {
                            settingsRow(title: "Badges", systemImage: "medal.fill")
                        }
                        Divider().overlay(AppColors.hairline).padding(.leading, 40)
                        Button {
                            navigation.openNotifications()
                        } label: {
                            settingsRow(title: "Notifications", systemImage: "bell.fill")
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(AppColors.hairline).padding(.leading, 40)
                        NavigationLink {
                            LettersView()
                        } label: {
                            settingsRow(title: "Letters & certificates", systemImage: "doc.text.fill")
                        }
                    }
                }

                Button(role: .destructive) {
                    authStore.logout()
                } label: {
                    Text("Sign out")
                        .font(CGTypography.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(AppColors.danger)
                        .background(AppColors.dangerContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, duoMode.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, duoMode.chatClearance)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(CGScreenBackground())
        .navigationTitle("Profile")
        .commonGroundToolbar()
        // Avoid SecureField/TextField focus thrash while saving.
        .onChange(of: isEditingPersonal) { _, editing in
            if !editing { focusedField = nil }
        }
        .onAppear { syncPersonalFields() }
        .onChange(of: authStore.session?.fullName) { _, _ in
            if !isEditingPersonal { syncPersonalFields() }
        }
        .overlay(alignment: .top) {
            if let personalToast {
                CGBanner(kind: .success, text: personalToast)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var personalInfoBox: some View {
        CGSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Personal info")
                        .font(CGTypography.label)
                        .foregroundStyle(AppColors.textMuted)
                    Spacer()
                    if isEditingPersonal {
                        Button("Cancel") {
                            syncPersonalFields()
                            isEditingPersonal = false
                            focusedField = nil
                        }
                        .font(CGTypography.sans(12, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            isEditingPersonal = true
                            focusedField = .name
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(CGTypography.sans(12, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.accentText)
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    personalField(
                        title: "Full name",
                        text: $fullName,
                        field: .name,
                        keyboard: .default,
                        contentType: .name
                    )
                    personalField(
                        title: "Phone",
                        text: $phone,
                        field: .phone,
                        keyboard: .phonePad,
                        contentType: .telephoneNumber,
                        placeholder: "Add a phone number"
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(CGTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                        Text(authStore.session?.email ?? "—")
                            .font(CGTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppColors.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if let error = authStore.errorMessage, isEditingPersonal {
                    CGBanner(kind: .error, text: error)
                }

                if isEditingPersonal {
                    CGPrimaryButton(
                        title: "Save changes",
                        busy: authStore.isBusy,
                        enabled: !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task { await savePersonalInfo() }
                    }
                }
            }
        }
    }

    private func personalField(
        title: String,
        text: Binding<String>,
        field: PersonalField,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        placeholder: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CGTypography.caption)
                .foregroundStyle(AppColors.textMuted)
            TextField(placeholder.isEmpty ? title : placeholder, text: text)
                .font(CGTypography.body)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(field == .name ? .words : .never)
                .disabled(!isEditingPersonal)
                .focused($focusedField, equals: field)
                .padding(14)
                .background(
                    (isEditingPersonal ? AppColors.surface : AppColors.canvas.opacity(0.7)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isEditingPersonal ? AppColors.hairline : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.heroGradient)
                        .frame(width: 72, height: 72)
                    Text(initials)
                        .font(CGTypography.sectionTitle)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(authStore.session?.fullName ?? "—")
                            .font(CGTypography.sectionTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        CGRoleBadge(label: authStore.session?.roleLabel ?? "Volunteer")
                    }
                    Text(authStore.session?.email ?? "")
                        .font(CGTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColors.primaryContainer.opacity(0.85), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }

    private func settingsRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.accentText)
                .frame(width: 22)
            Text(title)
                .font(CGTypography.bodyEmphasis)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
    }

    private func syncPersonalFields() {
        fullName = authStore.session?.fullName ?? ""
        phone = authStore.session?.phone ?? ""
    }

    private func savePersonalInfo() async {
        focusedField = nil
        let ok = await authStore.updateProfile(fullName: fullName, phone: phone)
        guard ok else { return }
        isEditingPersonal = false
        withAnimation(.easeOut(duration: 0.2)) {
            personalToast = "Personal info saved"
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation { personalToast = nil }
            }
        }
    }

    private var initials: String {
        let name = authStore.session?.fullName ?? "?"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}
