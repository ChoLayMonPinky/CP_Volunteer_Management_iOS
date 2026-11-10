import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var navigation: NavigationStore
    var skipSplash: Bool = false
    var restoreSession: Bool = true
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Always fill Duo cover / trailing status strip — never leave system white.
            AppColors.canvas.ignoresSafeArea()

            Group {
                if authStore.session == nil {
                    AuthView()
                } else {
                    MainShellView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(showSplash && !skipSplash ? 0 : 1)

            if showSplash && !skipSplash {
                SplashView {
                    showSplash = false
                }
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: authStore.session?.accessToken) { _, token in
            if token == nil {
                navigation.reset()
            }
        }
        .task {
            // Actor-isolated; starts a background health ping (does not block splash).
            await APIClient.shared.warmup()
            if skipSplash {
                showSplash = false
            }
            if restoreSession {
                authStore.restoreSession()
            }
        }
    }
}
