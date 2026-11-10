import Foundation
import UIKit
import UserNotifications

/// Registers the APNs device token with `POST /api/me/devices` after login.
/// Remote delivery still requires a real APNs key/cert in Apple Developer + Firebase (or your sender).
@MainActor
final class PushRegistration: NSObject {
    static let shared = PushRegistration()

    private var pendingTokenHex: String?
    private var accessToken: String?

    private override init() {
        super.init()
    }

    /// Call after login or session restore.
    func onAuthenticated(accessToken: String) {
        self.accessToken = accessToken
        requestPermissionAndRegister()
        if let pendingTokenHex {
            upload(tokenHex: pendingTokenHex)
        }
    }

    /// Best-effort unregister while the JWT is still valid, then clear local state.
    func onLoggedOut() async {
        if let accessToken, let pendingTokenHex, !pendingTokenHex.isEmpty {
            do {
                try await APIClient.shared.unregisterDevice(token: pendingTokenHex, accessToken: accessToken)
                NSLog("[PushRegistration] Unregistered APNs device token")
            } catch {
                NSLog("[PushRegistration] Device token unregister failed: %@", error.localizedDescription)
            }
        }
        self.accessToken = nil
        pendingTokenHex = nil
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        pendingTokenHex = hex
        upload(tokenHex: hex)
    }

    func handleRegistrationError(_ error: Error) {
        NSLog("[PushRegistration] APNs registration failed: %@", error.localizedDescription)
    }

    private func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                NSLog("[PushRegistration] notification permission error: %@", error.localizedDescription)
            }
            guard granted else {
                NSLog("[PushRegistration] notification permission not granted")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func upload(tokenHex: String) {
        guard let accessToken, !accessToken.isEmpty, !tokenHex.isEmpty else { return }
        Task {
            do {
                try await APIClient.shared.registerDevice(platform: "IOS", token: tokenHex, accessToken: accessToken)
                NSLog("[PushRegistration] Registered APNs device token")
            } catch {
                NSLog("[PushRegistration] Device token registration failed: %@", error.localizedDescription)
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushRegistration.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushRegistration.shared.handleRegistrationError(error)
        }
    }
}
