import Foundation

struct User: Codable {
    let id: String
    let email: String
}

struct Profile: Codable {
    let id: String
    var display_name: String?
    var sex: String
    var date_of_birth: String?
    var age_years: Int?
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

struct PhotoUpload: Decodable {
    let path: String
    let url: String
    let content_type: String
    let size_bytes: Int
}

struct InsightResult: Decodable {
    let text: String
    let generated_at: String
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

struct WeightPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}

struct WeightTrend {
    let current: Double?
    let slopePerWeek: Double?
    let etaDate: Date?
    let status: String
    let recentPoints: [WeightPoint]
    let forecastPoints: [WeightPoint]

    static func calculate(entries: [Entry], goal: Double?) -> WeightTrend {
        let points = entries.compactMap { entry -> WeightPoint? in
            guard let weight = entry.weight_kg, let date = entryDate(entry.entry_date) else { return nil }
            return WeightPoint(date: date, value: weight)
        }.sorted { $0.date < $1.date }
        let current = points.last?.value
        let recent = Array(points.suffix(10))
        guard recent.count >= 2 else {
            return WeightTrend(current: current, slopePerWeek: nil, etaDate: nil, status: goal == nil ? "no-goal" : "not-enough-data", recentPoints: recent, forecastPoints: [])
        }

        let times = recent.map { $0.date.timeIntervalSince1970 * 1_000 }
        let values = recent.map(\.value)
        let meanTime = times.reduce(0, +) / Double(times.count)
        let meanValue = values.reduce(0, +) / Double(values.count)
        let numerator = zip(times, values).reduce(0.0) { $0 + ($1.0 - meanTime) * ($1.1 - meanValue) }
        let denominator = times.reduce(0.0) { $0 + pow($1 - meanTime, 2) }
        let slopePerMillisecond = denominator == 0 ? 0 : numerator / denominator
        let slope = slopePerMillisecond * 86_400_000 * 7
        guard let goal else { return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "no-goal", recentPoints: recent, forecastPoints: []) }
        guard let last = recent.last else { return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "not-enough-data", recentPoints: recent, forecastPoints: []) }
        if (goal < (points.first?.value ?? goal) && (current ?? goal) <= goal) || (goal > (points.first?.value ?? goal) && (current ?? goal) >= goal) {
            return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "reached", recentPoints: recent, forecastPoints: [])
        }
        guard abs(slope) >= 0.02 else { return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "flat", recentPoints: recent, forecastPoints: []) }
        let projectedDifference = goal - meanValue
        guard projectedDifference * slope > 0 else { return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "wrong-way", recentPoints: recent, forecastPoints: []) }
        let milliseconds = projectedDifference / slopePerMillisecond
        guard milliseconds.isFinite, milliseconds > 0 else { return WeightTrend(current: current, slopePerWeek: slope, etaDate: nil, status: "flat", recentPoints: recent, forecastPoints: []) }
        let cap: Double = 86_400_000 * 365 * 3
        let forecastDate = last.date.addingTimeInterval(min(milliseconds, cap) / 1000)
        let forecast = [
            WeightPoint(date: last.date, value: last.value),
            WeightPoint(date: forecastDate, value: last.value + slopePerMillisecond * min(milliseconds, cap))
        ]
        return WeightTrend(current: current, slopePerWeek: slope, etaDate: milliseconds <= cap ? forecastDate : nil, status: "on-track", recentPoints: recent, forecastPoints: forecast)
    }
}

func entryDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: value)
}

func bodyFatOf(_ entry: Entry?, profile: Profile?) -> Double? {
    guard let entry else { return nil }
    return entry.body_fat_pct ?? profile.flatMap { NavyBodyFat.estimate(profile: $0, neck: entry.neck_cm, waist: entry.waist_cm, hip: entry.hip_cm) }
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
    var date_of_birth: String?
    var age_years: Int?
    var height_cm: Double?
    var goal_weight_kg: Double?
}

struct BasalMetabolicRate {
    static func estimate(profile: Profile, weightKg: Double?) -> Double? {
        guard let age = profile.age_years, let height = profile.height_cm,
              let weightKg, weightKg > 0, height > 0 else { return nil }
        let sexOffset = profile.sex == "male" ? 5.0 : -161.0
        return 10 * weightKg + 6.25 * height - 5 * Double(age) + sexOffset
    }
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
