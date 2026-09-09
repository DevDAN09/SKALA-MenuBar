import Foundation
import UserNotifications

public protocol CommuteNotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleWeekdayReminders() async
}

public final class CommuteNotificationService: CommuteNotificationServiceProtocol, @unchecked Sendable {
    public static let shared = CommuteNotificationService()

    public static let morningNotificationId = "skala.commute.morning.checkin"
    public static let eveningNotificationId = "skala.commute.evening.checkout"

    private let center: UNUserNotificationCenter?
    private let kstTimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    public init(center: UNUserNotificationCenter? = nil) {
        if let center = center {
            self.center = center
        } else if Bundle.main.bundleIdentifier != nil {
            self.center = UNUserNotificationCenter.current()
        } else {
            self.center = nil
        }
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard let center = center else {
            return false
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func makeMorningNotificationRequest(for weekday: Int) -> UNNotificationRequest {
        let morningContent = UNMutableNotificationContent()
        morningContent.title = "⏰ [SKALA] 출석 확인 알림"
        morningContent.body = "8시 50분입니다. 오늘 입실(출석) 체크하셨나요?"
        morningContent.sound = .default

        var morningComps = DateComponents()
        morningComps.timeZone = kstTimeZone
        morningComps.weekday = weekday
        morningComps.hour = 8
        morningComps.minute = 50

        let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningComps, repeats: true)
        return UNNotificationRequest(
            identifier: "\(Self.morningNotificationId).\(weekday)",
            content: morningContent,
            trigger: morningTrigger
        )
    }

    public func makeEveningNotificationRequest(for weekday: Int) -> UNNotificationRequest {
        let eveningContent = UNMutableNotificationContent()
        eveningContent.title = "👋 [SKALA] 퇴근 체크인 알림"
        eveningContent.body = "17시 50분입니다. 지금 퇴실(퇴근) 체크가 가능합니다!"
        eveningContent.sound = .default

        var eveningComps = DateComponents()
        eveningComps.timeZone = kstTimeZone
        eveningComps.weekday = weekday
        eveningComps.hour = 17
        eveningComps.minute = 50

        let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningComps, repeats: true)
        return UNNotificationRequest(
            identifier: "\(Self.eveningNotificationId).\(weekday)",
            content: eveningContent,
            trigger: eveningTrigger
        )
    }

    public func buildNotificationRequests() -> [UNNotificationRequest] {
        // Weekdays: Monday(2) ~ Friday(6)
        let weekdays = [2, 3, 4, 5, 6]
        var requests: [UNNotificationRequest] = []
        for weekday in weekdays {
            requests.append(makeMorningNotificationRequest(for: weekday))
            requests.append(makeEveningNotificationRequest(for: weekday))
        }
        return requests
    }

    public func scheduleWeekdayReminders() async {
        guard let center = center else {
            return
        }

        // Remove existing to avoid duplication
        var idsToRemove = [Self.morningNotificationId, Self.eveningNotificationId]
        for weekday in [2, 3, 4, 5, 6] {
            idsToRemove.append("\(Self.morningNotificationId).\(weekday)")
            idsToRemove.append("\(Self.eveningNotificationId).\(weekday)")
        }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        let requests = buildNotificationRequests()
        for req in requests {
            do {
                try await center.add(req)
            } catch {
                print("[CommuteNotificationService] Failed to schedule notification: \(error)")
            }
        }
    }
}
