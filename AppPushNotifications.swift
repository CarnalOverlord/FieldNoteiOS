import Foundation
import Combine
import UIKit
import UserNotifications

extension Notification.Name {
    static let fieldNoteOpenToday = Notification.Name("fieldnote.open-today")
}

@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var enabled = false
    @Published private(set) var requiresSettings = false
    @Published private(set) var message = "Weekly reminders are off."

    private let center = UNUserNotificationCenter.current()
    private let enabledKey = "fieldnote.push.enabled"
    private let deviceIDKey = "fieldnote.push.device-id"
    private let tokenKey = "fieldnote.push.device-token"
    private let syncedUserKey = "fieldnote.push.synced-user"
    private let syncedTokenKey = "fieldnote.push.synced-token"
    private let syncedTimezoneKey = "fieldnote.push.synced-timezone"
    private var activeUserID: String?

    private init() {
        enabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    var deviceID: String {
        if let value = UserDefaults.standard.string(forKey: deviceIDKey) { return value }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: deviceIDKey)
        return value
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let wantsReminders = UserDefaults.standard.bool(forKey: enabledKey)
        enabled = wantsReminders && authorized
        requiresSettings = wantsReminders && !authorized

        if enabled {
            message = "A weekly check-in reminder is enabled."
            UIApplication.shared.registerForRemoteNotifications()
        } else if wantsReminders && !authorized {
            message = "Notifications are disabled in iPhone Settings. Turn them on for FieldNote to receive reminders."
            await removeRegistration()
        } else {
            message = "Weekly reminders are off."
        }
    }

    func setEnabled(_ shouldEnable: Bool) async {
        guard shouldEnable else {
            enabled = false
            requiresSettings = false
            UserDefaults.standard.set(false, forKey: enabledKey)
            UIApplication.shared.unregisterForRemoteNotifications()
            await removeRegistration()
            message = "Weekly reminders are off."
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                enabled = false
                requiresSettings = true
                UserDefaults.standard.set(false, forKey: enabledKey)
                message = "Allow notifications in iPhone Settings to receive check-in reminders."
                return
            }
            UserDefaults.standard.set(true, forKey: enabledKey)
            enabled = true
            requiresSettings = false
            message = "Weekly check-in reminders are enabled."
            UIApplication.shared.registerForRemoteNotifications()
            await syncTokenIfReady()
        } catch {
            enabled = false
            requiresSettings = true
            UserDefaults.standard.set(false, forKey: enabledKey)
            message = "Notification permission could not be requested. Try again in iPhone Settings."
        }
    }

    func syncIfEnabled(userID: String) async {
        activeUserID = userID
        await refreshAuthorization()
        await syncTokenIfReady()
    }

    func receiveDeviceToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        await syncTokenIfReady()
    }

    func reportRegistrationFailure() {
        message = "Could not register this iPhone for reminders. Check your connection and try again."
    }

    func sendTestReminder() async {
        do {
            try await APIClient.shared.sendPushTest(deviceID: deviceID)
            message = "Test reminder accepted by Apple Push Notifications. Delivery may take a short time."
        } catch {
            message = error.localizedDescription
        }
    }

    func removeRegistrationForSignOut() async {
        await removeRegistration()
        activeUserID = nil
    }

    private func syncTokenIfReady() async {
        guard enabled, let activeUserID,
              let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        let environment: String
        #if DEBUG
        environment = "development"
        #else
        environment = "production"
        #endif

        let timezone = TimeZone.current.identifier
        if UserDefaults.standard.string(forKey: syncedUserKey) == activeUserID,
           UserDefaults.standard.string(forKey: syncedTokenKey) == token,
           UserDefaults.standard.string(forKey: syncedTimezoneKey) == timezone,
           UserDefaults.standard.string(forKey: "fieldnote.push.synced-environment") == environment { return }

        do {
            try await APIClient.shared.registerPushToken(
                deviceID: deviceID,
                token: token,
                environment: environment,
                timezone: timezone
            )
            UserDefaults.standard.set(activeUserID, forKey: syncedUserKey)
            UserDefaults.standard.set(token, forKey: syncedTokenKey)
            UserDefaults.standard.set(timezone, forKey: syncedTimezoneKey)
            UserDefaults.standard.set(environment, forKey: "fieldnote.push.synced-environment")
            message = "A weekly check-in reminder is enabled."
        } catch {
            message = "Could not save reminder settings: \(error.localizedDescription)"
        }
    }

    private func removeRegistration() async {
        guard activeUserID != nil else { return }
        do {
            try await APIClient.shared.removePushToken(deviceID: deviceID)
            UserDefaults.standard.removeObject(forKey: syncedUserKey)
            UserDefaults.standard.removeObject(forKey: syncedTokenKey)
            UserDefaults.standard.removeObject(forKey: syncedTimezoneKey)
            UserDefaults.standard.removeObject(forKey: "fieldnote.push.synced-environment")
        } catch {
            message = "Could not remove this device’s reminder registration: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class FieldNoteAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushNotificationManager.shared.receiveDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { PushNotificationManager.shared.reportRegistrationFailure() }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(name: .fieldNoteOpenToday, object: nil)
        completionHandler()
    }
}
