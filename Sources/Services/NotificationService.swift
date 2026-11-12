import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var revision = 0
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func replace(events: [CalendarEvent]) async -> String {
        revision += 1
        let token = revision
        let settings = await center.notificationSettings()
        guard token == revision else { return "" }
        center.removeAllPendingNotificationRequests()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return "Thông báo chưa được bật. Lịch vẫn được lưu."
        }
        let plan = ReminderPlan.upcoming(events)
        for item in plan {
            guard token == revision else { return "" }
            let content = UNMutableNotificationContent()
            content.title = item.event.title
            content.body = "\(item.occurrence.formatted(date: .abbreviated, time: .shortened))\(item.event.location.isEmpty ? "" : " · " + item.event.location)"
            content.sound = .default
            content.userInfo = ["eventID": item.event.id]
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(identifier: item.id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do { try await center.add(request) }
            catch { return "Không thể đặt đầy đủ lời nhắc: \(error.localizedDescription)" }
            // A newer replacement may run while add() is suspended. Remove only our obsolete request.
            if token != revision { center.removePendingNotificationRequests(withIdentifiers: [item.id]); return "" }
        }
        return "Đã đặt \(plan.count) lời nhắc sắp tới trên iPhone này."
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
