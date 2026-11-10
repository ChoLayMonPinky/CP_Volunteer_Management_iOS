import Foundation
import Network

struct PendingCheckIn: Codable, Identifiable, Equatable, Sendable {
    var id: String { eventId }
    let eventId: String
    let eventName: String?
    let code: String
    let queuedAt: Date
}

@MainActor
final class OfflineCheckInStore: ObservableObject {
    static let shared = OfflineCheckInStore()

    @Published private(set) var pending: [PendingCheckIn] = []
    @Published private(set) var flushing = false
    @Published private(set) var pathSatisfied = true

    private let defaults = UserDefaults.standard
    private let key = "cg.offlineCheckIns"
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "cg.offline.monitor")
    private var flushTask: Task<Void, Never>?
    private var flushAgain = false
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        load()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                self.pathSatisfied = online
                if online { self.requestFlush() }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func enqueue(eventId: String, eventName: String?, code: String) {
        let item = PendingCheckIn(
            eventId: eventId,
            eventName: eventName,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            queuedAt: Date()
        )
        pending.removeAll { $0.eventId == eventId }
        pending.append(item)
        persist()
    }

    func remove(eventId: String) {
        pending.removeAll { $0.eventId == eventId }
        persist()
    }

    func clearAll() {
        flushTask?.cancel()
        flushTask = nil
        flushAgain = false
        flushing = false
        pending = []
        defaults.removeObject(forKey: key)
    }

    func requestFlush(token: String? = nil) {
        if flushing {
            flushAgain = true
            return
        }
        flushTask = Task { await flush(token: token) }
    }

    func flush(token: String?) async {
        guard !flushing else {
            flushAgain = true
            return
        }
        // Prefer the live session token; never flush with a stale UserDefaults token after logout.
        let authToken = token
        guard let authToken, !authToken.isEmpty, !pending.isEmpty else { return }

        flushing = true
        defer {
            flushing = false
            if flushAgain {
                flushAgain = false
                requestFlush(token: authToken)
            }
        }

        let snapshot = pending
        for item in snapshot {
            do {
                _ = try await APIClient.shared.selfCheckIn(
                    eventId: item.eventId,
                    code: item.code,
                    token: authToken
                )
                remove(eventId: item.eventId)
            } catch {
                if isAlreadyCheckedIn(error) {
                    remove(eventId: item.eventId)
                } else if !isTransient(error) {
                    remove(eventId: item.eventId)
                }
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func isTransient(_ error: Error) -> Bool {
        if let api = error as? APIError {
            switch api {
            case .http(let code, let body):
                if code >= 500 { return true }
                let msg = (body ?? "").lowercased()
                return msg.contains("network") || msg.contains("timeout") || msg.contains("connection")
            case .message(let text):
                let msg = text.lowercased()
                return msg.contains("network") || msg.contains("internet") || msg.contains("reach")
                    || msg.contains("timed") || msg.contains("took too long") || msg.contains("connection")
                    || msg.contains("waking up")
            default:
                return false
            }
        }
        if error is URLError { return true }
        return false
    }

    private func isAlreadyCheckedIn(_ error: Error) -> Bool {
        let msg = (error as? APIError)?.localizedDescription.lowercased()
            ?? error.localizedDescription.lowercased()
        return msg.contains("already checked") || msg.contains("already check-in")
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else {
            pending = []
            return
        }
        if let decoded = try? decoder.decode([PendingCheckIn].self, from: data) {
            pending = decoded
            return
        }
        // Legacy payloads encoded without ISO-8601 — drop rather than crash.
        pending = []
        defaults.removeObject(forKey: key)
    }

    private func persist() {
        if let data = try? encoder.encode(pending) {
            defaults.set(data, forKey: key)
        }
    }
}
