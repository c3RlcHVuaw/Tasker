import Foundation
import UserNotifications

enum RecurringTaskNotifications {
    private static let identifierPrefix = "recurring-task."
    private static let testIdentifier = "recurring-task.test"

    static func refresh(
        tasks: [TaskItem],
        enabled: Bool,
        hour: Int,
        minute: Int
    ) async {
        let center = UNUserNotificationCenter.current()

        let pendingRequests = await center.pendingRequests()
        let recurringIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        if !recurringIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: recurringIdentifiers)
        }

        guard enabled else { return }

        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            settings = await center.notificationSettings()
        }

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let now = Date()
        for task in tasks where task.recurrence != .none {
            guard task.date > now else { continue }
            guard let fireDate = scheduledDate(baseDate: task.date, hour: hour, minute: minute) else { continue }
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Повторяющаяся задача"
            content.body = task.text.isEmpty ? "Пора выполнить задачу" : task.text
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + task.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func scheduledDate(baseDate: Date, hour: Int, minute: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    @discardableResult
    static func sendTestNotification() async -> Bool {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            settings = await center.notificationSettings()
        }

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return false
        }

        center.removePendingNotificationRequests(withIdentifiers: [testIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Tasker"
        content.body = "Тестовое уведомление работает."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: testIdentifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}

private extension UNUserNotificationCenter {
    func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

}
