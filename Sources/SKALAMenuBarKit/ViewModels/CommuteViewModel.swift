import Foundation
import Combine

@MainActor
public final class CommuteViewModel: ObservableObject {
    @Published public private(set) var isInternalNetwork: Bool = false
    @Published public private(set) var isCheckOutAllowed: Bool = false
    @Published public private(set) var currentTimeString: String = ""
    @Published public private(set) var countdownString: String? = nil
    @Published public private(set) var isCheckingNetwork: Bool = false
    @Published public private(set) var isNotificationAuthorized: Bool = false

    private static let reminderEnabledKey = "isCommuteReminderEnabled"
    @Published public var isReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReminderEnabled, forKey: Self.reminderEnabledKey)
            Task {
                if isReminderEnabled {
                    let granted = await notificationService.requestAuthorization()
                    if granted {
                        await notificationService.scheduleWeekdayReminders()
                    } else {
                        self.isReminderEnabled = false
                        UserDefaults.standard.set(false, forKey: Self.reminderEnabledKey)
                    }
                } else {
                    await notificationService.cancelReminders()
                }
                await updateNotificationStatus()
            }
        }
    }

    private static let developerModeKey = "isCommuteDeveloperModeEnabled"
    @Published public var isDeveloperModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDeveloperModeEnabled, forKey: Self.developerModeKey)
        }
    }

    private var devModeClickCount = 0
    private var lastDevModeClickTime: Date = .distantPast

    private let service: CommuteServiceProtocol
    private let notificationService: CommuteNotificationServiceProtocol
    private var timer: AnyCancellable?
    private let kstTimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!
    private let timeFormatter: DateFormatter

    public init(
        service: CommuteServiceProtocol = CommuteService.shared,
        notificationService: CommuteNotificationServiceProtocol = CommuteNotificationService.shared
    ) {
        self.service = service
        self.notificationService = notificationService
        let savedSetting = UserDefaults.standard.object(forKey: Self.reminderEnabledKey) as? Bool ?? true
        self.isReminderEnabled = savedSetting

        let savedDevMode = UserDefaults.standard.bool(forKey: Self.developerModeKey)
        self.isDeveloperModeEnabled = savedDevMode

        let formatter = DateFormatter()
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "HH:mm:ss"
        self.timeFormatter = formatter
        updateClock()
        startTimer()
    }

    public func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateClock()
            }
    }

    public func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    public func updateClock(at date: Date = Date()) {
        currentTimeString = timeFormatter.string(from: date)

        isCheckOutAllowed = service.isCheckOutAllowed(at: date)

        if let diff = service.timeUntilCheckOut(at: date) {
            if diff.hours > 0 {
                countdownString = "\(diff.hours)시간 \(diff.minutes)분 남음"
            } else if diff.minutes > 0 {
                countdownString = "\(diff.minutes)분 \(diff.seconds)초 남음"
            } else {
                countdownString = "\(diff.seconds)초 남음"
            }
        } else {
            countdownString = nil
        }
    }

    public func refresh() async {
        guard !isCheckingNetwork else { return }
        isCheckingNetwork = true
        isInternalNetwork = await service.checkInternalNetwork()
        isCheckingNetwork = false
        updateClock()
        await updateNotificationStatus()
    }

    public func updateNotificationStatus() async {
        isNotificationAuthorized = await notificationService.checkAuthorizationStatus()
    }

    public func registerDeveloperModeClick() {
        let now = Date()
        if now.timeIntervalSince(lastDevModeClickTime) > 2.5 {
            devModeClickCount = 1
        } else {
            devModeClickCount += 1
        }
        lastDevModeClickTime = now

        if devModeClickCount >= 5 {
            devModeClickCount = 0
            isDeveloperModeEnabled.toggle()
            if isDeveloperModeEnabled {
                Task {
                    await refresh()
                }
            }
        }
    }

    public func triggerCheckIn() {
        CommuteWebWindowController.shared.show(url: service.targetURL)
    }

    public func triggerCheckOut() {
        guard isCheckOutAllowed else { return }
        CommuteWebWindowController.shared.show(url: service.targetURL)
    }

    public func requestNotificationPermission() async {
        let granted = await notificationService.requestAuthorization()
        if granted {
            await notificationService.scheduleWeekdayReminders()
        }
        await updateNotificationStatus()
    }

    deinit {
        timer?.cancel()
    }
}
