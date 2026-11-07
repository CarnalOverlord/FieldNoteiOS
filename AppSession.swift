import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published var isLoading = true
    @Published var isSignedIn = false
    @Published var dashboardData: Dashboard?
    @Published var entries: [Entry] = []
    @Published var profile: Profile?
    @Published var errorMessage: String?

    init() {
        isSignedIn = KeychainStore.read() != nil
        isLoading = false
    }

    func signIn(email: String, password: String, register: Bool) async {
        errorMessage = nil
        do {
            let result = try await APIClient.shared.authenticate(email: email, password: password, register: register)
            try KeychainStore.save(result.access_token)
            isSignedIn = true
            await loadDashboard()
        } catch { errorMessage = error.localizedDescription }
    }

    func loadDashboard() async {
        guard isSignedIn else { return }
        do {
            async let dashboard = APIClient.shared.dashboard()
            async let history = APIClient.shared.entries()
            let (summary, list) = try await (dashboard, history)
            dashboardData = summary
            profile = summary.profile
            entries = list.items.sorted { $0.entry_date > $1.entry_date }
            errorMessage = nil
        } catch {
            if KeychainStore.read() == nil {
                isSignedIn = false
            } else { errorMessage = error.localizedDescription }
        }
    }

    func save(date: Date, weight: String, neck: String, waist: String, hip: String, chest: String, arm: String, thigh: String, photoPath: String?, notes: String) async throws {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let dateString = String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
        let payload = EntryPayload(weight_kg: parseMeasurement(weight), neck_cm: parseMeasurement(neck), waist_cm: parseMeasurement(waist), hip_cm: parseMeasurement(hip), chest_cm: parseMeasurement(chest), arm_cm: parseMeasurement(arm), thigh_cm: parseMeasurement(thigh), body_fat_pct: nil, photo_path: photoPath, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes)
        guard payload.weight_kg != nil || payload.neck_cm != nil || payload.waist_cm != nil || payload.hip_cm != nil || payload.chest_cm != nil || payload.arm_cm != nil || payload.thigh_cm != nil || photoPath != nil else {
            throw APIError(message: "Add a weight, measurement, or progress photo before saving.")
        }
        _ = try await APIClient.shared.saveEntry(date: dateString, payload: payload)
        await loadDashboard()
    }

    func signOut() async {
        await APIClient.shared.logout()
        dashboardData = nil
        entries = []
        profile = nil
        isSignedIn = false
    }

    func saveProfile(name: String, sex: String, height: String, goal: String) async throws {
        let payload = ProfilePayload(display_name: name.isEmpty ? nil : name, sex: sex, height_cm: parseMeasurement(height), goal_weight_kg: parseMeasurement(goal))
        profile = try await APIClient.shared.updateProfile(payload)
        await loadDashboard()
    }
}
