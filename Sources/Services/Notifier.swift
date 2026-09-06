import Foundation
import UserNotifications

final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum Notifier {
    private static var requested = false

    static func requestAuthorizationIfNeeded() {
        guard !requested else { return }
        requested = true
        let center = UNUserNotificationCenter.current()
        center.delegate = ForegroundNotificationDelegate.shared
        Task {
            try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    static func notifyDownloadFinished(title: String, success: Bool) {
        let content = UNMutableNotificationContent()
        content.title = success ? "下载完成" : "下载失败"
        content.body = title
        if success {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
