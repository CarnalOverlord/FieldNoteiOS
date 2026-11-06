import Foundation

struct User: Codable {
    let id: String
    let email: String
}

struct Profile: Codable {
    let id: String
    var display_name: String?
    var sex: String
    var height_cm: Double?
    var goal_weight_kg: Double?
    var last_insight: String?
    var last_insight_at: String?
    var updated_at: String?
}

struct Entry: Codable, Identifiable {
    let id: String
    let entry_date: String
    var weight_kg: Double?
    var neck_cm: Double?
    var waist_cm: Double?
    var hip_cm: Double?
    var chest_cm: Double?
    var arm_cm: Double?
    var thigh_cm: Double?
    var body_fat_pct: Double?
    var photo_path: String?
    var photo_url: String?
    var notes: String?
    var ai_insight: String?
    var ai_insight_at: String?
    var created_at: String?
}

struct TokenResponse: Decodable {
    let user: User
    let access_token: String
    let token_type: String
    let expires_at: String
}

struct AuthEnvelope: Decodable {
    let user: User
    let profile: Profile?
}

struct EntryList: Decodable {
    let items: [Entry]
    let next_cursor: String?
}

struct Dashboard: Decodable {
    let profile: Profile
    let latest_entry: Entry?
    let previous_entry: Entry?
    let first_entry: Entry?
    let latest_measurement_entry: Entry?
    let photo_entries: [Entry]
    let forecast: Forecast?
    let days_since_weigh_in: Int?
    let weigh_in_due: Bool
}

struct Forecast: Decodable {
    let slope_per_week: Double
    let current: Double
    let eta_date: String?
    let status: String
}

struct Problem: Decodable {
    let title: String?
    let code: String?
    let detail: String?
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct EntryPayload: Encodable {
    var weight_kg: Double?
    var neck_cm: Double?
    var waist_cm: Double?
    var hip_cm: Double?
    var chest_cm: Double?
    var arm_cm: Double?
    var thigh_cm: Double?
    var body_fat_pct: Double?
    var photo_path: String?
    var notes: String?
}

struct ProfilePayload: Encodable {
    var display_name: String?
    var sex: String
    var height_cm: Double?
    var goal_weight_kg: Double?
}

struct NavyBodyFat {
    static func estimate(profile: Profile, neck: Double?, waist: Double?, hip: Double?) -> Double? {
        guard let height = profile.height_cm, height > 0,
              let neck, neck > 0, let waist, waist > 0 else { return nil }
        let value: Double
        if profile.sex == "male" {
            guard waist > neck else { return nil }
            value = 495 / (1.0324 - 0.19077 * log10(waist - neck) + 0.15456 * log10(height)) - 450
        } else {
            guard let hip, hip > 0, waist + hip > neck else { return nil }
            value = 495 / (1.29579 - 0.35004 * log10(waist + hip - neck) + 0.221 * log10(height)) - 450
        }
        guard value.isFinite, (2...70).contains(value) else { return nil }
        return (value * 10).rounded() / 10
    }
}

func parseMeasurement(_ value: String) -> Double? {
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return nil }
    return Double(cleaned.replacingOccurrences(of: ",", with: "."))
}

func displayDate(_ date: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    guard let parsed = formatter.date(from: date) else { return date }
    formatter.dateStyle = .medium
    formatter.dateFormat = nil
    return formatter.string(from: parsed)
}
