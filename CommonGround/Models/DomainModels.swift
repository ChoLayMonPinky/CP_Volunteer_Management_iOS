import Foundation

// MARK: - Events / registrations

struct ApiRegistration: Decodable, Identifiable, Sendable {
    let id: String
    let eventId: String?
    let eventName: String?
    let eventDate: String?
    let startTime: String?
    let venue: String?
    let userId: String?
    let userName: String?
    let userEmail: String?
    let status: String?
    let hours: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.flexID(c, .id) ?? UUID().uuidString
        eventId = Self.flexID(c, .eventId)
        eventName = try c.decodeIfPresent(String.self, forKey: .eventName)
        eventDate = try c.decodeIfPresent(String.self, forKey: .eventDate)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        venue = try c.decodeIfPresent(String.self, forKey: .venue)
        userId = Self.flexID(c, .userId)
        userName = try c.decodeIfPresent(String.self, forKey: .userName)
        userEmail = try c.decodeIfPresent(String.self, forKey: .userEmail)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        hours = c.decodeFlexibleDouble(forKey: .hours)
    }

    private enum CodingKeys: String, CodingKey {
        case id, eventId, eventName, eventDate, startTime, venue
        case userId, userName, userEmail, status, hours
    }

    private static func flexID(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let u = try? c.decode(UUID.self, forKey: key) { return u.uuidString }
        return nil
    }

    var displayName: String {
        if let userName, !userName.isEmpty { return userName }
        if let userEmail, !userEmail.isEmpty { return userEmail }
        return "Volunteer"
    }

    var statusKey: String { (status ?? "").uppercased() }
}

// MARK: - Hours

struct ApiHourLog: Decodable, Identifiable, Sendable {
    let id: String
    let eventName: String?
    let workDate: String?
    let hours: Double?
    let description: String?
    let status: String?
    let source: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = UUID().uuidString
        }
        eventName = try c.decodeIfPresent(String.self, forKey: .eventName)
        workDate = try c.decodeIfPresent(String.self, forKey: .workDate)
        hours = c.decodeFlexibleDouble(forKey: .hours)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        source = try c.decodeIfPresent(String.self, forKey: .source)
    }

    private enum CodingKeys: String, CodingKey {
        case id, eventName, workDate, hours, description, status, source
    }
}

struct HourLogRequest: Encodable, Sendable {
    let workDate: String
    let hours: Double
    let description: String?
    let eventId: String?
}

// MARK: - Tasks

struct ApiTask: Decodable, Identifiable, Sendable {
    let id: String
    let title: String?
    let description: String?
    let priority: String?
    let status: String?
    let dueDate: String?
    let eventName: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = UUID().uuidString
        }
        title = try c.decodeIfPresent(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        priority = try c.decodeIfPresent(String.self, forKey: .priority)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        eventName = try c.decodeIfPresent(String.self, forKey: .eventName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status, dueDate, eventName
    }
}

struct TaskStatusRequest: Encodable, Sendable {
    let status: String
}

// MARK: - Badges

struct ApiBadge: Decodable, Identifiable, Sendable {
    var id: String { "\(hours ?? 0)-\(title ?? "")" }
    let hours: Int?
    let title: String?
    let tier: String?
    let earned: Bool?
    let earnedDate: String?
    let progress: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hours = c.decodeFlexibleInt(forKey: .hours)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        tier = try c.decodeIfPresent(String.self, forKey: .tier)
        earned = try c.decodeIfPresent(Bool.self, forKey: .earned)
        earnedDate = try c.decodeIfPresent(String.self, forKey: .earnedDate)
        progress = c.decodeFlexibleDouble(forKey: .progress)
    }

    private enum CodingKeys: String, CodingKey {
        case hours, title, tier, earned, earnedDate, progress
    }
}

struct ApiBadgeSummary: Decodable, Sendable {
    let totalHours: Double?
    let current: ApiBadge?
    let next: ApiBadge?
    let badges: [ApiBadge]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalHours = c.decodeFlexibleDouble(forKey: .totalHours)
        current = try c.decodeIfPresent(ApiBadge.self, forKey: .current)
        next = try c.decodeIfPresent(ApiBadge.self, forKey: .next)
        badges = try c.decodeIfPresent([ApiBadge].self, forKey: .badges)
    }

    private enum CodingKeys: String, CodingKey {
        case totalHours, current, next, badges
    }
}

// MARK: - Notifications

struct ApiNotification: Decodable, Identifiable, Sendable {
    let id: String
    let type: String?
    let title: String?
    let body: String?
    let read: Bool?
    let createdAt: String?

    init(
        id: String,
        type: String? = nil,
        title: String? = nil,
        body: String? = nil,
        read: Bool? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.read = read
        self.createdAt = createdAt
    }

    init(copying other: ApiNotification, read: Bool?) {
        self.init(
            id: other.id,
            type: other.type,
            title: other.title,
            body: other.body,
            read: read,
            createdAt: other.createdAt
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = UUID().uuidString
        }
        type = try c.decodeIfPresent(String.self, forKey: .type)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        read = try c.decodeIfPresent(Bool.self, forKey: .read)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, title, body, read, createdAt
    }
}

struct NotificationsPage: Decodable, Sendable {
    let unreadCount: Int?
    let items: [ApiNotification]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unreadCount = c.decodeFlexibleInt(forKey: .unreadCount)
        items = try c.decodeIfPresent([ApiNotification].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case unreadCount, items
    }
}

struct EmptyJSON: Decodable, Sendable {}

struct DeviceTokenRequest: Encodable, Sendable {
    let platform: String
    let token: String
}

struct DeviceTokenResponse: Decodable, Sendable {
    let id: String?
    let platform: String?
    let updatedAt: String?
}

// Shared flexible number helpers (file-private duplicates AuthModels helpers via internal)
extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let i = try? decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? decode(String.self, forKey: key) { return Int(s) }
        return nil
    }
}
