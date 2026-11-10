import SwiftUI

@main
struct CommonGroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authStore = AuthStore()
    @StateObject private var appearanceStore = AppearanceStore()
    @StateObject private var navigationStore = NavigationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(appearanceStore)
                .environmentObject(navigationStore)
                .preferredColorScheme(appearanceStore.appearance.colorScheme)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
