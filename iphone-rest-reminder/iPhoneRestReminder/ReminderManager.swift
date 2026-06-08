import Combine
import Foundation
import UserNotifications

@MainActor
final class ReminderManager: ObservableObject {
    static let eyeInterval: TimeInterval = 20 * 60
    static let bodyInterval: TimeInterval = 60 * 60
    static let inactivityPauseThreshold: TimeInterval = 2 * 60
    static let longRestInterval: TimeInterval = 5 * 60
    static let notificationHorizon: TimeInterval = 12 * 60 * 60

    @Published private(set) var eyeRemaining = eyeInterval
    @Published private(set) var bodyRemaining = bodyInterval
    @Published private(set) var notificationsEnabled = false

    private let startDateKey = "reminderStartDate"
    private let backgroundedAtKey = "reminderBackgroundedAt"
    private var startDate: Date
    private var timer: AnyCancellable?

    init() {
        if let savedDate = UserDefaults.standard.object(forKey: startDateKey) as? Date {
            startDate = savedDate
        } else {
            startDate = Date()
            UserDefaults.standard.set(startDate, forKey: startDateKey)
        }

        refresh()
        startTimer()

        Task {
            await updateNotificationStatus()
            if notificationsEnabled {
                await scheduleNotifications()
            }
        }
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationsEnabled = granted
            if granted {
                resetStartDate()
                await scheduleNotifications()
            }
        } catch {
            notificationsEnabled = false
        }
    }

    func reset() {
        resetStartDate()
        refresh()

        rescheduleNotificationsIfEnabled()
    }

    func sceneDidEnterBackground() {
        UserDefaults.standard.set(Date(), forKey: backgroundedAtKey)
    }

    func sceneDidBecomeActive() {
        let defaults = UserDefaults.standard
        guard let backgroundedAt = defaults.object(forKey: backgroundedAtKey) as? Date else {
            refresh()
            return
        }

        defaults.removeObject(forKey: backgroundedAtKey)
        let timeAway = Date().timeIntervalSince(backgroundedAt)
        var shouldRescheduleNotifications = false

        if timeAway >= Self.longRestInterval {
            resetStartDate()
            shouldRescheduleNotifications = true
        } else if timeAway >= Self.inactivityPauseThreshold {
            let pausedDuration = timeAway - Self.inactivityPauseThreshold
            startDate = startDate.addingTimeInterval(pausedDuration)
            defaults.set(startDate, forKey: startDateKey)
            shouldRescheduleNotifications = true
        }

        refresh()

        if shouldRescheduleNotifications {
            rescheduleNotificationsIfEnabled()
        }
    }

    func refresh() {
        let elapsed = max(0, Date().timeIntervalSince(startDate))
        eyeRemaining = Self.remaining(in: Self.eyeInterval, elapsed: elapsed)
        bodyRemaining = Self.remaining(in: Self.bodyInterval, elapsed: elapsed)
    }

    func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    private func updateNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let eyeContent = UNMutableNotificationContent()
        eyeContent.title = "该让眼睛休息了"
        eyeContent.body = "望向远处 20 秒，让眼睛放松一下。"
        eyeContent.sound = .default

        let bodyContent = UNMutableNotificationContent()
        bodyContent.title = "该离开屏幕休息了"
        bodyContent.body = "休息 5 分钟，起身活动并放松肩颈。"
        bodyContent.sound = .default

        await scheduleNotificationSeries(
            center: center,
            identifierPrefix: "eye-reminder",
            content: eyeContent,
            firstDelay: eyeRemaining,
            interval: Self.eyeInterval
        )
        await scheduleNotificationSeries(
            center: center,
            identifierPrefix: "body-reminder",
            content: bodyContent,
            firstDelay: bodyRemaining,
            interval: Self.bodyInterval
        )
    }

    private func scheduleNotificationSeries(
        center: UNUserNotificationCenter,
        identifierPrefix: String,
        content: UNNotificationContent,
        firstDelay: TimeInterval,
        interval: TimeInterval
    ) async {
        var delay = max(1, firstDelay)
        var index = 0

        while delay <= Self.notificationHorizon {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: delay,
                repeats: false
            )
            try? await center.add(
                UNNotificationRequest(
                    identifier: "\(identifierPrefix)-\(index)",
                    content: content,
                    trigger: trigger
                )
            )
            delay += interval
            index += 1
        }
    }

    private static func remaining(in interval: TimeInterval, elapsed: TimeInterval) -> TimeInterval {
        let remainder = elapsed.truncatingRemainder(dividingBy: interval)
        return remainder == 0 && elapsed > 0 ? interval : interval - remainder
    }

    private func resetStartDate() {
        startDate = Date()
        UserDefaults.standard.set(startDate, forKey: startDateKey)
    }

    private func rescheduleNotificationsIfEnabled() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsEnabled = settings.authorizationStatus == .authorized
            guard notificationsEnabled else {
                return
            }

            await scheduleNotifications()
        }
    }
}
