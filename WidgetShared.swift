import Foundation
import WidgetKit

enum WidgetShared {
    static let suite = "group.co.za.drkflm.fieldnote"
    static let url = URL(string: "fieldnote://log-today")!

    static func save(weight: Double?, heightCm: Double?, date: String?) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set(weight, forKey: "latestWeightKg")
        defaults.set(heightCm, forKey: "heightCm")
        defaults.set(date, forKey: "latestWeightDate")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
