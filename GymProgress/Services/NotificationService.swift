import Foundation
import UserNotifications

enum NotificationService {
    static func schedule(for workout: ScheduledWorkout) async {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") { return }
        cancel(workoutID: workout.id)
        guard workout.status == .planned,
              let minutes = workout.reminderMinutes else { return }

        let fireDate = workout.scheduledAt.addingTimeInterval(TimeInterval(-minutes * 60))
        guard fireDate > .now else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }

        let content = UNMutableNotificationContent()
        content.title = "Скоро тренировка"
        content.body = "\(workout.templateName) начнётся в \(workout.scheduledAt.formatted(date: .omitted, time: .shortened))."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(workout.id),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancel(workoutID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(workoutID)]
        )
    }

    private static func identifier(_ id: UUID) -> String { "scheduled-workout-\(id.uuidString)" }
}
