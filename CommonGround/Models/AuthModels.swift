import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthUser: Decodable, Equatable, Sendable {
    let id: String?
    let email: String?
    let fullName: String?
    let role: String?
    let phone: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeFlexString(c, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        if let roleString = try c.decodeIfPresent(String.self, forKey: .role) {
            role = roleString
        } else {
            role = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, email, fullName, role, phone
    }

    private static func decodeFlexString(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let u = try? c.decode(UUID.self, forKey: key) { return u.uuidString }
        return nil
    }
}

struct AuthResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String?
    let user: AuthUser?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let token = try c.decodeIfPresent(String.self, forKey: .accessToken), !token.isEmpty {
            accessToken = token
        } else if let token = try c.decodeIfPresent(String.self, forKey: .token), !token.isEmpty {
            accessToken = token
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.accessToken,
                .init(codingPath: c.codingPath, debugDescription: "accessToken missing")
            )
        }
        tokenType = try c.decodeIfPresent(String.self, forKey: .tokenType)
        user = try c.decodeIfPresent(AuthUser.self, forKey: .user)
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken, token, tokenType, user
    }
}

struct UpdateProfileRequest: Encodable {
    let fullName: String?
    let phone: String?
}

struct AuthSession: Equatable, Sendable {
    let volunteerId: String
    let email: String
    let fullName: String
    let role: String
    let accessToken: String
    var phone: String

    init(
        volunteerId: String,
        email: String,
        fullName: String,
        role: String,
        accessToken: String,
        phone: String = ""
    ) {
        self.volunteerId = volunteerId
        self.email = email
        self.fullName = fullName
        self.role = role
        self.accessToken = accessToken
        self.phone = phone
    }

    var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }

    var roleLabel: String {
        switch role.uppercased() {
        case "ORGANIZER", "ADMIN": return "Admin"
        case "VOLUNTEER_LEADER", "EVENT_LEADER": return "Leader"
        default: return "Volunteer"
        }
    }

    var isAdmin: Bool {
        ["ORGANIZER", "ADMIN"].contains(role.uppercased())
    }

    var isLeader: Bool {
        ["VOLUNTEER_LEADER", "EVENT_LEADER"].contains(role.uppercased())
    }

    /// Create event / org publish (matches Android organiser + leader).
    var canCreateEvents: Bool { isAdmin || isLeader }

    /// Leader roll-call attendance (matches Android Attendance tab).
    var canManageAttendance: Bool { isAdmin || isLeader }
}

struct ChatMessageDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let role: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

struct ChatRequest: Encodable, Sendable {
    let message: String
    let history: [ChatMessageDTO]?
}

struct ChatResponse: Decodable, Sendable {
    let reply: String
}

struct MySummary: Decodable, Sendable {
    let totalHours: Double?
    let pendingHourLogs: Int?
    let upcomingRegistrations: Int?
    let completedEvents: Int?
    let openTasks: Int?
    let unreadNotifications: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalHours = c.decodeFlexibleDouble(forKey: .totalHours)
        pendingHourLogs = c.decodeFlexibleInt(forKey: .pendingHourLogs)
        upcomingRegistrations = c.decodeFlexibleInt(forKey: .upcomingRegistrations)
        completedEvents = c.decodeFlexibleInt(forKey: .completedEvents)
        openTasks = c.decodeFlexibleInt(forKey: .openTasks)
        unreadNotifications = c.decodeFlexibleInt(forKey: .unreadNotifications)
    }

    private enum CodingKeys: String, CodingKey {
        case totalHours, pendingHourLogs, upcomingRegistrations
        case completedEvents, openTasks, unreadNotifications
    }
}

struct ApiEvent: Decodable, Identifiable, Sendable {
    let id: String
    let name: String?
    let description: String?
    let category: String?
    let date: String?
    let startTime: String?
    let endTime: String?
    let venue: String?
    let address: String?
    let remote: Bool?
    let status: String?
    let capacity: Int?
    let registeredCount: Int?
    let checkInCode: String?
    let myRegistrationStatus: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                .init(codingPath: c.codingPath, debugDescription: "Event id missing")
            )
        }
        name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        date = Self.decodeDateLike(c, forKey: .date)
        startTime = Self.decodeDateLike(c, forKey: .startTime)
        endTime = Self.decodeDateLike(c, forKey: .endTime)
        venue = try c.decodeIfPresent(String.self, forKey: .venue)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        remote = try c.decodeIfPresent(Bool.self, forKey: .remote)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        capacity = c.decodeFlexibleInt(forKey: .capacity)
        registeredCount = c.decodeFlexibleInt(forKey: .registeredCount)
        checkInCode = try c.decodeIfPresent(String.self, forKey: .checkInCode)
        myRegistrationStatus = try c.decodeIfPresent(String.self, forKey: .myRegistrationStatus)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, date, startTime, endTime, venue, address, remote
        case status, capacity, registeredCount, checkInCode, myRegistrationStatus
    }

    private static func decodeDateLike(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        return nil
    }

    var isRegistered: Bool {
        let s = (myRegistrationStatus ?? "").uppercased()
        return !s.isEmpty && s != "CANCELLED" && s != "NO_SHOW"
    }

    var canSelfCheckIn: Bool {
        let s = (myRegistrationStatus ?? "").uppercased()
        return s == "CONFIRMED" || s == "NO_SHOW"
    }
}

struct EventCreateRequest: Encodable, Sendable {
    let name: String
    let description: String?
    let category: String?
    let venue: String?
    let address: String?
    let remote: Bool
    let meetingLink: String?
    let date: String
    let startTime: String
    let endTime: String
    let capacity: Int
    let status: String?
    let imageUrl: String?
}

struct SelfCheckInRequest: Encodable, Sendable {
    let code: String
}

struct RegistrationResponse: Decodable, Sendable {
    let id: String?
    let status: String?
    let eventName: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = nil
        }
        status = try c.decodeIfPresent(String.self, forKey: .status)
        eventName = try c.decodeIfPresent(String.self, forKey: .eventName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, eventName
    }
}

struct APIErrorBody: Decodable {
    let message: String?
}
