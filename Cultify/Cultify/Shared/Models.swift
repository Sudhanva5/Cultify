import Foundation

// MARK: - User & auth

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let name: String
}

struct TokenResponse: Codable {
    let access_token: String
    let user: User
}

// MARK: - Exercise

struct ExerciseReference: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let body_part: String?
    let equipment: String?
    let target_muscle: String?
    let gif_path: String?
}

struct ExerciseLog: Codable, Identifiable, Hashable {
    let id: String
    let exercise_ref_id: String?
    let custom_name: String?
    let logged_at: Date
    let sets: Int?
    let reps: Int?
    let weight_kg: Double?
    let duration_minutes: Int?
    let notes: String?
    // joined
    let name: String?
    let body_part: String?
    let gif_path: String?

    var displayName: String { name ?? custom_name ?? "Exercise" }
    var summary: String {
        if let s = sets, let r = reps {
            if let w = weight_kg, w > 0 { return "\(s) × \(r) @ \(formatted(w)) kg" }
            return "\(s) × \(r)"
        }
        if let d = duration_minutes { return "\(d) min" }
        return "—"
    }
    private func formatted(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Food

struct FoodLog: Codable, Identifiable, Hashable {
    let id: String
    let logged_at: Date
    let meal_type: String?
    let photo_path: String?
    let description: String?
    let estimated_calories: Double?
    let estimated_protein_g: Double?
    let estimated_carbs_g: Double?
    let estimated_fat_g: Double?
    let claude_food_analysis: String?
}

// MARK: - Sleep

struct SleepLog: Codable, Identifiable, Hashable {
    let id: String
    let date: String  // ISO date "YYYY-MM-DD"
    let slept_at: Date
    let woke_at: Date
    let duration_hours: Double?
}

// MARK: - Weight

struct WeightLog: Codable, Identifiable, Hashable {
    let id: String
    let logged_at: Date
    let weight_kg: Double
}

// MARK: - Analysis

struct Nutrition: Codable, Hashable {
    let calories_consumed: Double?
    let protein_consumed: Double?
    let calories_target: Double?
    let protein_target: Double?
    let efficiency_pct: Double?
    let suggestion: String?
}

struct DailyAnalysis: Codable, Identifiable, Hashable {
    let id: String
    let analysis_date: String  // ISO date
    let day_remark: String?
    let nutrition_json: Nutrition?
    let weight_projection: String?
    let recommendations: [String]?
    let generated_at: Date
}

// MARK: - Chat

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let role: String  // "user" or "assistant"
    let content: String
    let created_at: Date
}

struct ChatTodayResponse: Codable {
    let messages: [ChatMessage]
    let messages_used: Int
    let limit: Int
}

struct ChatSendResponse: Codable {
    let response: String
    let messages_used: Int
    let limit: Int
}
