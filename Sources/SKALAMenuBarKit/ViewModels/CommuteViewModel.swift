import Foundation
import Combine

@MainActor
public final class CommuteViewModel: ObservableObject {
    @Published public private(set) var isInternalNetwork: Bool = false
    @Published public private(set) var isCheckOutAllowed: Bool = false
    @Published public private(set) var currentTimeString: String = ""
    @Published public private(set) var countdownString: String? = nil
    @Published public private(set) var isCheckingNetwork: Bool = false

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
    }

    public func triggerCheckIn() {
        CommuteWebWindowController.shared.show(url: service.targetURL)
    }

    public func triggerCheckOut() {
        guard isCheckOutAllowed else { return }
        CommuteWebWindowController.shared.show(url: service.targetURL)
    }

    deinit {
        timer?.cancel()
    }
}
