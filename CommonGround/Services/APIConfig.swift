import Foundation

enum APIConfig {
    /// Backend base URL (no trailing slash). Override via Info.plist `API_BASE_URL`.
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !cleaned.isEmpty,
               !cleaned.contains("$("),
               let url = URL(string: cleaned) {
                return url
            }
        }
        return URL(string: "https://volunteer-backend-7m4w.onrender.com")!
    }
}
