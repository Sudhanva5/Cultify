import Foundation
import UIKit

enum APIError: LocalizedError {
    case http(Int, String)
    case decoding(Error)
    case transport(Error)
    case unauthorized
    case rateLimited(used: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .http(_, let msg):     return msg
        case .decoding(let e):      return "Decoding error: \(e.localizedDescription)"
        case .transport(let e):     return e.localizedDescription
        case .unauthorized:         return "Not signed in"
        case .rateLimited(_, let lim): return "Daily chat limit reached (\(lim)/\(lim))"
        }
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        session = URLSession(configuration: cfg)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            if let v = formatter.date(from: s) { return v }
            if let v = fallback.date(from: s) { return v }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Request builder

    private func makeRequest(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = "application/json"
    ) throws -> URLRequest {
        var comps = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else {
            throw APIError.http(0, "Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let ct = contentType { req.setValue(ct, forHTTPHeaderField: "Content-Type") }
        if let body { req.httpBody = body }
        if let token = SessionStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func run<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.http(0, "No HTTP response")
        }
        if http.statusCode == 401 {
            // Only clear if we actually had a token — otherwise we'd nuke the
            // dev placeholder user every time a call fails unauthenticated.
            if SessionStore.shared.token != nil {
                SessionStore.shared.signOut()
            }
            throw APIError.unauthorized
        }
        if http.statusCode == 429 {
            // Try to surface used/limit from the FastAPI detail dict
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] as? [String: Any],
               let used = detail["messages_used"] as? Int,
               let lim = detail["limit"] as? Int {
                throw APIError.rateLimited(used: used, limit: lim)
            }
            throw APIError.rateLimited(used: AppConfig.chatDailyLimit, limit: AppConfig.chatDailyLimit)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = parseDetail(data) ?? "HTTP \(http.statusCode)"
            throw APIError.http(http.statusCode, msg)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func parseDetail(_ data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = obj["detail"] as? String { return s }
            if let d = obj["detail"] as? [String: Any], let s = d["error"] as? String { return s }
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Auth

    func register(email: String, password: String, name: String) async throws -> TokenResponse {
        let body = try encoder.encode(["email": email, "password": password, "name": name])
        let req = try makeRequest("POST", "/auth/register", body: body)
        return try await run(req, as: TokenResponse.self)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let body = try encoder.encode(["email": email, "password": password])
        let req = try makeRequest("POST", "/auth/login", body: body)
        return try await run(req, as: TokenResponse.self)
    }

    func me() async throws -> User {
        let req = try makeRequest("GET", "/auth/me")
        return try await run(req, as: User.self)
    }

    // MARK: - Exercises

    func listExercises(bodyPart: String?, search: String?, cultOnly: Bool = true) async throws -> [ExerciseReference] {
        var q: [URLQueryItem] = [
            URLQueryItem(name: "cult_only", value: cultOnly ? "true" : "false"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        if let bp = bodyPart, bp.lowercased() != "all" {
            q.append(URLQueryItem(name: "body_part", value: bp.lowercased()))
        }
        if let s = search, !s.isEmpty {
            q.append(URLQueryItem(name: "search", value: s))
        }
        let req = try makeRequest("GET", "/exercises", query: q)
        return try await run(req, as: [ExerciseReference].self)
    }

    // MARK: - Exercise logs

    struct ExerciseLogPayload: Encodable {
        var exercise_ref_id: String?
        var custom_name: String?
        var sets: Int?
        var reps: Int?
        var weight_kg: Double?
        var duration_minutes: Int?
    }

    func logExercise(_ p: ExerciseLogPayload) async throws -> ExerciseLog {
        let body = try encoder.encode(p)
        let req = try makeRequest("POST", "/logs/exercise", body: body)
        return try await run(req, as: ExerciseLog.self)
    }

    func listExerciseLogs(date: Date) async throws -> [ExerciseLog] {
        let req = try makeRequest("GET", "/logs/exercise", query: [URLQueryItem(name: "date", value: DateHelpers.isoDate(date))])
        return try await run(req, as: [ExerciseLog].self)
    }

    func deleteExerciseLog(id: String) async throws {
        let req = try makeRequest("DELETE", "/logs/exercise/\(id)")
        _ = try await run(req, as: EmptyResponse.self)
    }

    // MARK: - Sleep

    struct SleepPayload: Encodable {
        let date: String
        let slept_at: Date
        let woke_at: Date
    }

    func logSleep(date: Date, sleptAt: Date, wokeAt: Date) async throws -> SleepLog {
        let p = SleepPayload(date: DateHelpers.isoDate(date), slept_at: sleptAt, woke_at: wokeAt)
        let body = try encoder.encode(p)
        let req = try makeRequest("POST", "/logs/sleep", body: body)
        return try await run(req, as: SleepLog.self)
    }

    func getSleep(date: Date) async throws -> SleepLog? {
        let req = try makeRequest("GET", "/logs/sleep", query: [URLQueryItem(name: "date", value: DateHelpers.isoDate(date))])
        do {
            return try await run(req, as: SleepLog.self)
        } catch APIError.decoding {
            // Endpoint returns `null` when no row exists — decode fails on null
            return nil
        }
    }

    // MARK: - Food

    func logFood(photo: UIImage, mealType: String, description: String) async throws -> FoodLog {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = try makeRequest("POST", "/logs/food", contentType: "multipart/form-data; boundary=\(boundary)")
        guard let imgData = photo.jpegData(compressionQuality: 0.7) else {
            throw APIError.http(0, "Could not encode photo")
        }

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"photo\"; filename=\"meal.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imgData)
        append("\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"meal_type\"\r\n\r\n")
        append(mealType)
        append("\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"description\"\r\n\r\n")
        append(description)
        append("\r\n")
        append("--\(boundary)--\r\n")

        req.httpBody = body
        return try await run(req, as: FoodLog.self)
    }

    func listFood(date: Date) async throws -> [FoodLog] {
        let req = try makeRequest("GET", "/logs/food", query: [URLQueryItem(name: "date", value: DateHelpers.isoDate(date))])
        return try await run(req, as: [FoodLog].self)
    }

    func deleteFood(id: String) async throws {
        let req = try makeRequest("DELETE", "/logs/food/\(id)")
        _ = try await run(req, as: EmptyResponse.self)
    }

    // MARK: - Weight

    func logWeight(_ kg: Double) async throws -> WeightLog {
        let body = try encoder.encode(["weight_kg": kg])
        let req = try makeRequest("POST", "/logs/weight", body: body)
        return try await run(req, as: WeightLog.self)
    }

    func listWeight(days: Int = 30) async throws -> [WeightLog] {
        let req = try makeRequest("GET", "/logs/weight", query: [URLQueryItem(name: "days", value: String(days))])
        return try await run(req, as: [WeightLog].self)
    }

    // MARK: - Analysis

    func analysis(date: Date) async throws -> DailyAnalysis? {
        let req = try makeRequest("GET", "/analysis", query: [URLQueryItem(name: "date", value: DateHelpers.isoDate(date))])
        // The endpoint returns either an Analysis or `{"status":"not_generated"}`
        do {
            return try await run(req, as: DailyAnalysis.self)
        } catch APIError.decoding {
            return nil
        }
    }

    // MARK: - Chat

    func chatToday() async throws -> ChatTodayResponse {
        let req = try makeRequest("GET", "/chat/today")
        return try await run(req, as: ChatTodayResponse.self)
    }

    func chatSend(_ message: String) async throws -> ChatSendResponse {
        let body = try encoder.encode(["message": message])
        let req = try makeRequest("POST", "/chat", body: body)
        return try await run(req, as: ChatSendResponse.self)
    }

    // MARK: - Asset URLs

    func staticURL(_ path: String?) -> URL? {
        guard let p = path, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        return AppConfig.apiBaseURL.appending(path: "/static/").appending(path: p)
    }

    func uploadURL(_ path: String?) -> URL? {
        guard let p = path, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        return AppConfig.apiBaseURL.appending(path: "/uploads/").appending(path: p)
    }
}

struct EmptyResponse: Decodable {}
