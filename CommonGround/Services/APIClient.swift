import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String?)
    case decoding(String)
    case unauthorized
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .http(_, let body): return body?.isEmpty == false ? body : "Request failed."
        case .decoding(let detail): return "Could not read the server response. (\(detail))"
        case .unauthorized: return "Please sign in again."
        case .message(let text): return text
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 90
            config.timeoutIntervalForResource = 120
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// Fire-and-forget ping so Render can wake during splash (free-tier cold start ~45–60s).
    func warmup() {
        Task {
            var base = APIConfig.baseURL.absoluteString
            while base.hasSuffix("/") { base.removeLast() }
            guard let url = URL(string: base + "/actuator/health/liveness") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 120
            _ = try? await session.data(for: request)
        }
    }

    // MARK: Auth

    func login(email: String, password: String) async throws -> AuthResponse {
        try await post(path: "/api/auth/login", body: LoginRequest(email: email, password: password), token: nil)
    }

    func currentUser(token: String) async throws -> AuthUser {
        try await get(path: "/api/auth/me", token: token)
    }

    func updateProfile(fullName: String, phone: String, token: String) async throws -> AuthUser {
        try await patch(
            path: "/api/auth/me",
            body: UpdateProfileRequest(fullName: fullName, phone: phone),
            token: token
        )
    }

    // MARK: Me

    func mySummary(token: String) async throws -> MySummary {
        try await get(path: "/api/me/summary", token: token)
    }

    func myBadges(token: String) async throws -> ApiBadgeSummary {
        try await get(path: "/api/me/badges", token: token)
    }

    func myTasks(token: String) async throws -> [ApiTask] {
        try await get(path: "/api/me/tasks", token: token)
    }

    func myNotifications(token: String, limit: Int = 50) async throws -> NotificationsPage {
        try await get(path: "/api/me/notifications", query: ["limit": "\(limit)"], token: token)
    }

    func markNotificationRead(id: String, token: String) async throws -> ApiNotification {
        try await postEmpty(path: "/api/me/notifications/\(id)/read", token: token)
    }

    func markAllNotificationsRead(token: String) async throws {
        let _: EmptyJSON = try await postEmpty(path: "/api/me/notifications/read-all", token: token)
    }

    func registerDevice(platform: String, token: String, accessToken: String) async throws {
        let _: DeviceTokenResponse = try await post(
            path: "/api/me/devices",
            body: DeviceTokenRequest(platform: platform, token: token),
            token: accessToken
        )
    }

    func unregisterDevice(token: String, accessToken: String) async throws {
        try await delete(path: "/api/me/devices", query: ["token": token], token: accessToken)
    }

    // MARK: Events

    func upcomingEvents(token: String) async throws -> [ApiEvent] {
        try await get(path: "/api/events", query: ["upcoming": "true"], token: token)
    }

    func listEvents(upcoming: Bool = false, token: String) async throws -> [ApiEvent] {
        try await get(path: "/api/events", query: ["upcoming": upcoming ? "true" : "false"], token: token)
    }

    func event(id: String, token: String) async throws -> ApiEvent {
        try await get(path: "/api/events/\(id)", token: token)
    }

    func createEvent(_ body: EventCreateRequest, token: String) async throws -> ApiEvent {
        try await post(path: "/api/events", body: body, token: token)
    }

    func regenerateCheckInCode(eventId: String, token: String) async throws -> ApiEvent {
        try await postEmpty(path: "/api/events/\(eventId)/check-in-code", token: token)
    }

    func register(eventId: String, token: String) async throws -> ApiRegistration {
        try await postEmpty(path: "/api/events/\(eventId)/register", token: token)
    }

    func cancelRegistration(eventId: String, token: String) async throws {
        try await delete(path: "/api/events/\(eventId)/register", token: token)
    }

    func selfCheckIn(eventId: String, code: String, token: String) async throws -> RegistrationResponse {
        try await post(
            path: "/api/events/\(eventId)/check-in",
            body: SelfCheckInRequest(code: code),
            token: token
        )
    }

    func selfCheckOut(eventId: String, token: String) async throws -> RegistrationResponse {
        try await postEmpty(path: "/api/events/\(eventId)/check-out", token: token)
    }

    func eventRegistrations(eventId: String, token: String) async throws -> [ApiRegistration] {
        try await get(path: "/api/events/\(eventId)/registrations", token: token)
    }

    func staffCheckIn(eventId: String, registrationId: String, token: String) async throws -> ApiRegistration {
        try await postEmpty(
            path: "/api/events/\(eventId)/registrations/\(registrationId)/check-in",
            token: token
        )
    }

    func staffCheckOut(eventId: String, registrationId: String, token: String) async throws -> ApiRegistration {
        try await postEmpty(
            path: "/api/events/\(eventId)/registrations/\(registrationId)/check-out",
            token: token
        )
    }

    func markNoShow(eventId: String, registrationId: String, token: String) async throws -> ApiRegistration {
        try await postEmpty(
            path: "/api/events/\(eventId)/registrations/\(registrationId)/no-show",
            token: token
        )
    }

    func myRegistrations(token: String) async throws -> [ApiRegistration] {
        try await get(path: "/api/me/registrations", token: token)
    }

    // MARK: Hours

    func myHours(token: String) async throws -> [ApiHourLog] {
        try await get(path: "/api/hours/mine", token: token)
    }

    func submitHours(_ body: HourLogRequest, token: String) async throws -> ApiHourLog {
        try await post(path: "/api/hours", body: body, token: token)
    }

    // MARK: Tasks

    func setTaskStatus(id: String, status: String, token: String) async throws -> ApiTask {
        try await patch(path: "/api/tasks/\(id)/status", body: TaskStatusRequest(status: status), token: token)
    }

    // MARK: Chat

    func chat(message: String, history: [ChatMessageDTO], token: String) async throws -> ChatResponse {
        try await post(path: "/api/chat", body: ChatRequest(message: message, history: history), token: token)
    }

    // MARK: HTTP

    private func get<T: Decodable>(
        path: String,
        query: [String: String] = [:],
        token: String?
    ) async throws -> T {
        try await send(makeRequest(path: path, method: "GET", query: query, token: token))
    }

    private func post<Body: Encodable, T: Decodable>(
        path: String,
        body: Body,
        token: String?
    ) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private func postEmpty<T: Decodable>(path: String, token: String?) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await send(request)
    }

    private func patch<Body: Encodable, T: Decodable>(
        path: String,
        body: Body,
        token: String?
    ) async throws -> T {
        var request = try makeRequest(path: path, method: "PATCH", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private func delete(
        path: String,
        query: [String: String] = [:],
        token: String?
    ) async throws {
        let request = try makeRequest(path: path, method: "DELETE", query: query, token: token)
        let _: EmptyJSON = try await send(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [String: String] = [:],
        token: String?
    ) throws -> URLRequest {
        var base = APIConfig.baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        guard var components = URLComponents(string: base + trimmed) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
                .map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.message(Self.friendlyURLError(urlError))
        } catch {
            throw APIError.message(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("No HTTP response.")
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, Self.friendlyMessage(from: data))
        }

        if T.self == EmptyJSON.self {
            if data.isEmpty { return EmptyJSON() as! T }
            if let decoded = try? decoder.decode(T.self, from: data) { return decoded }
            return EmptyJSON() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(180), encoding: .utf8) ?? "invalid JSON"
            let reason = String(String(describing: error).prefix(120))
            throw APIError.decoding("\(reason) | \(snippet)")
        }
    }

    private static func friendlyURLError(_ error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "The server took too long to respond (it may be waking up). Try again."
        case .notConnectedToInternet, .dataNotAllowed:
            return "No internet connection."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Cannot reach the CommonGround server."
        case .networkConnectionLost:
            return "Network connection lost. Try again."
        default:
            return error.localizedDescription
        }
    }

    private static func friendlyMessage(from data: Data) -> String? {
        if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data),
           let message = body.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }
        // Spring validation often returns { "errors": { "email": "..." } }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = obj["message"] as? String,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            if let errors = obj["errors"] as? [String: Any] {
                let parts = errors.values.compactMap { $0 as? String }
                if !parts.isEmpty { return parts.joined(separator: " ") }
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }
}

