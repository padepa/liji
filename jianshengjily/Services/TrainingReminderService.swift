import Foundation
import UserNotifications

enum TrainingReminderWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static let displayOrder: [TrainingReminderWeekday] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday
    ]

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: L10n.string("周一")
        case .tuesday: L10n.string("周二")
        case .wednesday: L10n.string("周三")
        case .thursday: L10n.string("周四")
        case .friday: L10n.string("周五")
        case .saturday: L10n.string("周六")
        case .sunday: L10n.string("周日")
        }
    }
}

struct TrainingReminderSchedule: Equatable {
    var isEnabled: Bool
    var weekdays: Set<Int>
    var hour: Int
    var minute: Int

    static let defaultSchedule = TrainingReminderSchedule(
        isEnabled: false,
        weekdays: [
            TrainingReminderWeekday.monday.rawValue,
            TrainingReminderWeekday.wednesday.rawValue,
            TrainingReminderWeekday.friday.rawValue
        ],
        hour: 19,
        minute: 0
    )
}

enum TrainingReminderAuthorizationState: Equatable {
    case notDetermined
    case allowed
    case denied
}

enum TrainingReminderSaveResult {
    case scheduled
    case disabled
    case denied
}

enum TrainingReminderService {
    private static let notificationIdentifierPrefix = "liji.training-reminder.weekday-"
    private static let enabledKey = "trainingReminder.isEnabled"
    private static let weekdaysKey = "trainingReminder.weekdays"
    private static let hourKey = "trainingReminder.hour"
    private static let minuteKey = "trainingReminder.minute"

    static func loadSchedule(from defaults: UserDefaults = .standard) -> TrainingReminderSchedule {
        let fallback = TrainingReminderSchedule.defaultSchedule
        let storedWeekdays = defaults.array(forKey: weekdaysKey) as? [Int]
        let storedHour = defaults.object(forKey: hourKey) as? Int
        let storedMinute = defaults.object(forKey: minuteKey) as? Int

        return TrainingReminderSchedule(
            isEnabled: defaults.bool(forKey: enabledKey),
            weekdays: Set(storedWeekdays ?? Array(fallback.weekdays)),
            hour: storedHour ?? fallback.hour,
            minute: storedMinute ?? fallback.minute
        )
    }

    static func authorizationState(
        center: UNUserNotificationCenter = .current()
    ) async -> TrainingReminderAuthorizationState {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    static func save(
        _ schedule: TrainingReminderSchedule,
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) async throws -> TrainingReminderSaveResult {
        guard schedule.isEnabled else {
            persist(schedule, to: defaults)
            removeScheduledNotifications(from: center)
            return .disabled
        }

        let canNotify: Bool
        switch await authorizationState(center: center) {
        case .allowed:
            canNotify = true
        case .notDetermined:
            canNotify = try await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            canNotify = false
        }

        guard canNotify else {
            var disabledSchedule = schedule
            disabledSchedule.isEnabled = false
            persist(disabledSchedule, to: defaults)
            removeScheduledNotifications(from: center)
            return .denied
        }

        persist(schedule, to: defaults)
        removeScheduledNotifications(from: center)

        for weekday in schedule.weekdays.sorted() {
            let content = UNMutableNotificationContent()
            content.title = L10n.string("训练时间到了")
            content.body = L10n.string("给自己几分钟准备，打开力迹开始下一练。")
            content.sound = .default
            content.categoryIdentifier = "TRAINING_REMINDER"

            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = schedule.hour
            dateComponents.minute = schedule.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: weekday),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }

        return .scheduled
    }

    private static func persist(_ schedule: TrainingReminderSchedule, to defaults: UserDefaults) {
        defaults.set(schedule.isEnabled, forKey: enabledKey)
        defaults.set(schedule.weekdays.sorted(), forKey: weekdaysKey)
        defaults.set(schedule.hour, forKey: hourKey)
        defaults.set(schedule.minute, forKey: minuteKey)
    }

    private static func removeScheduledNotifications(from center: UNUserNotificationCenter) {
        let identifiers = TrainingReminderWeekday.allCases.map {
            notificationIdentifier(for: $0.rawValue)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func notificationIdentifier(for weekday: Int) -> String {
        "\(notificationIdentifierPrefix)\(weekday)"
    }
}
