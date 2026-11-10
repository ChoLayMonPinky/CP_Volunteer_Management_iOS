import SwiftUI

struct ContentView: View {
    var skipSplash: Bool = false
    var restoreSession: Bool = true

    var body: some View {
        RootView(skipSplash: skipSplash, restoreSession: restoreSession)
    }
}

#if DEBUG
private struct ContentViewPreviewHost: View {
    @StateObject private var authStore = AuthStore()
    @StateObject private var appearanceStore = AppearanceStore()
    @StateObject private var navigationStore = NavigationStore()

    var body: some View {
        ContentView(skipSplash: true, restoreSession: false)
            .environmentObject(authStore)
            .environmentObject(appearanceStore)
            .environmentObject(navigationStore)
            .preferredColorScheme(appearanceStore.appearance.colorScheme)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewPreviewHost()
    }
}
#endif
