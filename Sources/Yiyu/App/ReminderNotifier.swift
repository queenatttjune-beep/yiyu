import AppKit
import Foundation
import UserNotifications
import YiyuCore

/// Mirrors upcoming reminders into macOS notifications and plays a sound in-app
/// when notifications are turned off.
@MainActor
final class ReminderNotifier: NSObject, UNUserNotificationCenterDelegate {
    /// macOS keeps at most 64 pending notifications per app.
    private static let maxScheduled = 60
    /// Repeating reminders are scheduled this far ahead, so they still go off while the app is closed.
    private static let repeatHorizonDays = 7

    private let center: UNUserNotificationCenter?
    private let calendar: Calendar
    var onOpenReminders: (@MainActor () -> Void)?

    init(calendar: Calendar) {
        // UNUserNotificationCenter crashes outside an app bundle (e.g. `swift run`).
        self.center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
        self.calendar = calendar
        super.init()
        center?.delegate = self
    }

    /// Asks for permission (macOS shows the prompt once), then schedules whatever the
    /// reminders are by the time the user answers.
    func start(currentReminders: @escaping @MainActor () -> [Reminder]) {
        guard let center else { return }
        Task {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                NSLog("Yiyu: notification permission request failed: %@", error.localizedDescription)
            }
            sync(currentReminders())
        }
    }

    func sync(_ reminders: [Reminder], now: Date = Date()) {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
        let occurrences = ReminderBook.occurrences(
            of: reminders, after: now, days: Self.repeatHorizonDays, limit: Self.maxScheduled, calendar: calendar
        )
        for occurrence in occurrences {
            center.add(request(for: occurrence)) { error in
                if let error {
                    NSLog("Yiyu: scheduling a reminder notification failed: %@", error.localizedDescription)
                }
            }
        }
    }

    /// The system notification already makes a sound; chime in-app only when notifications are off.
    func reminderFiredInApp(_ fired: [Reminder]) {
        guard !fired.isEmpty else { return }
        guard let center else {
            NSSound(named: "Glass")?.play()
            return
        }
        center.getNotificationSettings { settings in
            let isAllowed = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                if !isAllowed {
                    NSSound(named: "Glass")?.play()
                }
            }
        }
    }

    private func request(for occurrence: ReminderBook.Occurrence) -> UNNotificationRequest {
        let reminder = occurrence.reminder
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.repeatRule == .none ? "到时间了" : "\(reminder.repeatRule.label)提醒"
        content.sound = .default
        // Carrying the time zone keeps the notification on the same moment the app uses after travel.
        let parts = calendar.dateComponents(
            [.timeZone, .year, .month, .day, .hour, .minute, .second], from: occurrence.date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let identifier = "\(reminder.id.uuidString)-\(Int(occurrence.date.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await openReminders()
    }

    private func openReminders() {
        onOpenReminders?()
    }
}
