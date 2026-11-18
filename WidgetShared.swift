import Foundation
import WidgetKit

enum WidgetShared {
    static let suite = "group.co.za.drkflm.fieldnote"
    static let url = URL(string: "fieldnote://log-today")!

    static func save(
        weight: Double?,
        heightCm: Double?,
        date: String?,
        bodyFatPct: Double?,
        bodyFatIsEstimate: Bool,
        isPremium: Bool,
        weightHistory: [WidgetWeightPoint]
    ) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set(weight, forKey: "latestWeightKg")
        defaults.set(heightCm, forKey: "heightCm")
        defaults.set(date, forKey: "latestWeightDate")
        defaults.set(bodyFatPct, forKey: "latestBodyFatPct")
        defaults.set(bodyFatIsEstimate, forKey: "latestBodyFatIsEstimate")
        defaults.set(isPremium, forKey: "premiumEnabled")
        if let history = try? JSONEncoder().encode(weightHistory) {
            defaults.set(history, forKey: "weightHistory")
        } else {
            defaults.removeObject(forKey: "weightHistory")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WidgetWeightPoint: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let weightKg: Double
}
