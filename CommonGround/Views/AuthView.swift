import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var showPassword = false

    var body: some View {
        ZStack(alignment: .top) {
            fullBleedBackground

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    formBlock
                        .padding(.top, -18)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fullBleedBackground: some View {
        ZStack(alignment: .top) {
            AppColors.canvas
            AppColors.heroGradient
                .frame(maxWidth: .infinity)
                .frame(height: 360)
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 40, y: -40)
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -40, y: 80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                )
            Text("CommonGround")
                .font(CGTypography.brandTitle)
                .foregroundStyle(.white)

            Text("Sign in to manage hours, events, and check-ins.")
                .font(CGTypography.body)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 36)
    }

    private var formBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome back")
                .font(CGTypography.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 12) {
                CGUIKitTextField(
                    text: $email,
                    placeholder: "Email",
                    keyboardType: .emailAddress,
                    textContentType: .username,
                    returnKeyType: .next
                )
                .cgUIKitFieldChrome()

                HStack(spacing: 10) {
                    CGUIKitTextField(
                        text: $password,
                        placeholder: "Password",
                        isSecure: !showPassword,
                        textContentType: .password,
                        returnKeyType: .go,
                        submitLabel: { Task { await signIn() } }
                    )
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.textMuted)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                .cgUIKitFieldChrome()

                Toggle(isOn: $rememberMe) {
                    Text("Keep me signed in")
                        .font(CGTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .tint(AppColors.primary)
            }

            if let error = authStore.errorMessage {
                CGBanner(kind: .error, text: error)
            }

            CGPrimaryButton(
                title: "Sign in",
                busy: authStore.isBusy,
                enabled: !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
            ) {
                Task { await signIn() }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private func signIn() async {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        await authStore.login(
            email: email,
            password: password,
            persist: rememberMe
        )
    }
}
