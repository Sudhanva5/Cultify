import Foundation

enum AppConfig {
    /// Override at runtime by adding a `CULTIFY_API_URL` entry to your scheme's
    /// environment variables (Edit Scheme → Run → Arguments → Environment Variables).
    /// Falls back to localhost for simulator dev.
    static var apiBaseURL: URL {
        if let s = ProcessInfo.processInfo.environment["CULTIFY_API_URL"],
           let url = URL(string: s) {
            return url
        }
        return URL(string: "http://localhost:8000")!
    }

    static let chatDailyLimit = 5
}
