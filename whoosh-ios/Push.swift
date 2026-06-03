import SwiftUI
import Combine
import UserNotifications
import UIKit

/// APNs push, no SDK. `PushAppDelegate` receives the device token from the
/// system; `PushManager` registers it with the backend once the API is ready and
/// surfaces tapped-notification deep links. Backend pushes for @mentions + DMs
/// via the `push-apns` Edge Function.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    /// "chat:<channelId>:<messageId>" from a tapped notification, consumed by the UI.
    @Published var pendingDeepLink: String?

    private var api: WhooshAPI?
    private var token: String?

    /// Called once signed in; registers any token we already received.
    func configure(api: WhooshAPI) {
        self.api = api
        if let token { Task { await register(token) } }
    }

    func setToken(_ token: String) {
        self.token = token
        Task { await register(token) }
    }

    private func register(_ token: String) async {
        try? await api?.registerDeviceToken(token)
    }

    /// Ask permission, then register with APNs (call after sign-in).
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}

final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in PushManager.shared.setToken(hex) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Non-fatal: in-app notifications still work without push.
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        if let href = response.notification.request.content.userInfo["href"] as? String {
            await MainActor.run { PushManager.shared.pendingDeepLink = href }
        }
    }
}
