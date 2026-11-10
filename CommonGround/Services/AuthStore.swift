import Foundation
import SwiftUI

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let tokenKey = "cg.accessToken"
    private let emailKey = "cg.email"
    private let nameKey = "cg.fullName"
    private let roleKey = "cg.role"
    private let idKey = "cg.userId"
    private let phoneKey = "cg.phone"

    /// Restores a persisted session. Does **not** clear an in-memory session
    /// when nothing is stored (important when “Keep me signed in” is off, and
    /// when SwiftUI re-runs `.task`).
    func restoreSession() {
        guard let token = defaults.string(forKey: tokenKey), !token.isEmpty,
              let email = defaults.string(forKey: emailKey),
              let name = defaults.string(forKey: nameKey),
              let role = defaults.string(forKey: roleKey),
              let id = defaults.string(forKey: idKey)
        else {
            return
        }
        session = AuthSession(
            volunteerId: id,
            email: email,
            fullName: name,
            role: role,
            accessToken: token,
            phone: defaults.string(forKey: phoneKey) ?? ""
        )
        PushRegistration.shared.onAuthenticated(accessToken: token)
    }

    func login(email: String, password: String, persist: Bool = true) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let secret = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !secret.isEmpty else {
            errorMessage = "Enter email and password."
            return
        }
        guard trimmed.contains("@") else {
            errorMessage = "Enter a valid email address."
            return
        }

        do {
            let response = try await APIClient.shared.login(email: trimmed, password: secret)
            let user = response.user
            let next = AuthSession(
                volunteerId: user?.id ?? trimmed,
                email: user?.email ?? trimmed,
                fullName: user?.fullName ?? trimmed,
                role: user?.role ?? "VOLUNTEER",
                accessToken: response.accessToken,
                phone: user?.phone ?? ""
            )
            apply(session: next, persist: persist)
            PushRegistration.shared.onAuthenticated(accessToken: next.accessToken)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Updates name + phone via `PATCH /api/auth/me`, then refreshes the local session.
    func updateProfile(fullName: String, phone: String) async -> Bool {
        guard let current = session else { return false }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Name can’t be empty."
            return false
        }

        do {
            let user = try await APIClient.shared.updateProfile(
                fullName: name,
                phone: phoneTrimmed,
                token: current.accessToken
            )
            let next = AuthSession(
                volunteerId: user.id ?? current.volunteerId,
                email: user.email ?? current.email,
                fullName: user.fullName ?? name,
                role: user.role ?? current.role,
                accessToken: current.accessToken,
                phone: user.phone ?? phoneTrimmed
            )
            let persist = defaults.string(forKey: tokenKey) != nil
            apply(session: next, persist: persist)
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func logout() {
        // Unregister while PushRegistration still holds the JWT + device token.
        Task { @MainActor in
            await PushRegistration.shared.onLoggedOut()
        }
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: roleKey)
        defaults.removeObject(forKey: idKey)
        defaults.removeObject(forKey: phoneKey)
        session = nil
        errorMessage = nil
        // Pending check-ins are user-scoped — never flush them under the next login.
        OfflineCheckInStore.shared.clearAll()
    }

    /// Maps API/network errors and signs out on 401.
    func friendlyMessage(for error: Error) -> String {
        if let api = error as? APIError {
            if case .unauthorized = api {
                Task { @MainActor in
                    self.logout()
                }
            }
            return api.localizedDescription
        }
        return error.localizedDescription
    }

    private func apply(session: AuthSession, persist: Bool) {
        if persist {
            defaults.set(session.accessToken, forKey: tokenKey)
            defaults.set(session.email, forKey: emailKey)
            defaults.set(session.fullName, forKey: nameKey)
            defaults.set(session.role, forKey: roleKey)
            defaults.set(session.volunteerId, forKey: idKey)
            defaults.set(session.phone, forKey: phoneKey)
        } else {
            defaults.removeObject(forKey: tokenKey)
            defaults.removeObject(forKey: emailKey)
            defaults.removeObject(forKey: nameKey)
            defaults.removeObject(forKey: roleKey)
            defaults.removeObject(forKey: idKey)
            defaults.removeObject(forKey: phoneKey)
        }
        self.session = session
    }
}
