import Foundation
import UserNotifications

@MainActor
enum ReminderService {
    static func schedule(for task: TaskItem) async {
        guard !task.isCompleted, let dueDate = task.dueDate else { return }
        let fireDate = reminderDate(for: dueDate)
        guard fireDate > .now else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        } else if settings.authorizationStatus == .denied {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Voice2Task"
        content.body = "Pendiente: \(task.title)" + (task.priority == .alta ? " · Prioridad alta" : "")
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    static func cancel(for task: TaskItem) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [task.id.uuidString])
    }

    private static func reminderDate(for dueDate: Date) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: dueDate)
        guard time.hour == 0, time.minute == 0, time.second == 0 else { return dueDate }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate) ?? dueDate
    }
}

final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
