import Foundation
import Combine

@MainActor
public final class SKCTTimerViewModel: ObservableObject {
    @Published public var totalSeconds: Int = 0
    @Published public var isRunning: Bool = false
    @Published public var isCountdown: Bool = false
    @Published public var isFinished: Bool = false

    private var timer: AnyCancellable?
    private var initialSeconds: Int = 0

    public init() {}

    public var minutes: Int { totalSeconds / 60 }
    public var seconds: Int { totalSeconds % 60 }

    public var timeString: String {
        String(format: "%02d:%02d", minutes, seconds)
    }

    public func addMinutes(_ mins: Int) {
        guard !isRunning else { return }
        isFinished = false
        totalSeconds = max(0, min(5999, totalSeconds + mins * 60))
        initialSeconds = totalSeconds
    }

    public func addSeconds(_ secs: Int) {
        guard !isRunning else { return }
        isFinished = false
        totalSeconds = max(0, min(5999, totalSeconds + secs))
        initialSeconds = totalSeconds
    }

    public func start() {
        guard !isRunning else { return }
        isFinished = false
        isCountdown = totalSeconds > 0
        if isCountdown && initialSeconds == 0 {
            initialSeconds = totalSeconds
        }
        isRunning = true

        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    public func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    public func reset() {
        pause()
        totalSeconds = 0
        initialSeconds = 0
        isCountdown = false
        isFinished = false
    }

    public func tick() {
        if isCountdown {
            if totalSeconds > 0 {
                totalSeconds -= 1
                if totalSeconds == 0 {
                    pause()
                    isFinished = true
                }
            } else {
                pause()
                isFinished = true
            }
        } else {
            totalSeconds += 1
        }
    }

    deinit {
        timer?.cancel()
    }
}
