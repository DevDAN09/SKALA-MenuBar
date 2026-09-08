import Foundation
import Combine

@MainActor
public final class BusViewModel: ObservableObject {
    private static let selectedBusKey = "PangyoBus_SelectedBus"

    @Published public var selectedBus: TargetBus {
        didSet {
            UserDefaults.standard.set(selectedBus.rawValue, forKey: Self.selectedBusKey)
            self.menuTitle = formatMenuTitle(allArrivals[selectedBus])
        }
    }

    @Published public private(set) var menuTitle: String = "🚌 버스: 로딩 중…"
    @Published public private(set) var allArrivals: [TargetBus: BusArrivalDetails] = [:]
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public var refreshIntervalSeconds: Int {
        didSet {
            setupTimer()
        }
    }

    private let apiService: BusAPIServiceProtocol
    private var timer: Timer?

    public init(apiService: BusAPIServiceProtocol = BusAPIService.shared, refreshInterval: Int = 30) {
        self.apiService = apiService
        self.refreshIntervalSeconds = refreshInterval

        if let savedRaw = UserDefaults.standard.string(forKey: Self.selectedBusKey),
           let savedBus = TargetBus(rawValue: savedRaw) {
            self.selectedBus = savedBus
        } else {
            self.selectedBus = .bus9007
        }

        setupTimer()
    }

    public func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(refreshIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let arrivals = try await apiService.fetchTargetBusesArrival()
            self.allArrivals = arrivals
            self.lastUpdated = Date()
            self.menuTitle = formatMenuTitle(arrivals[selectedBus])
        } catch {
            self.errorMessage = error.localizedDescription
            self.menuTitle = "⚠️ \(selectedBus.shortName): 확인 실패"
        }
        isLoading = false
    }

    public func formatMenuTitle(_ details: BusArrivalDetails?) -> String {
        let busName = selectedBus.shortName
        guard let details = details, let seconds = details.arrivalTime, seconds > 0 else {
            return "🚌 \(busName): 정보 없음"
        }

        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = details.busStopCount ?? 0

        if minutes <= 3 {
            return "🚨 \(busName): \(minutes)분 전 (\(stops)전)"
        } else {
            return "🚌 \(busName): \(minutes)분 (\(stops)전)"
        }
    }

    public func firstBusText(for bus: TargetBus) -> String {
        guard let arrival = allArrivals[bus], let seconds = arrival.arrivalTime, seconds > 0 else {
            return "도착 정보 없음 (차고지 대기 또는 운행 종료)"
        }
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = arrival.busStopCount.map { "\($0)정류장 전" } ?? ""
        let plate = arrival.vehicleNumber.map { " [\($0)]" } ?? ""
        return "약 \(minutes)분 뒤 도착 (\(stops))\(plate)"
    }

    public func secondBusText(for bus: TargetBus) -> String {
        guard let arrival = allArrivals[bus], let seconds = arrival.arrivalTime2, seconds > 0 else {
            return "다음 버스 도착 정보 없음"
        }
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = arrival.busStopCount2.map { "\($0)정류장 전" } ?? ""
        let plate = arrival.vehicleNumber2.map { " [\($0)]" } ?? ""
        return "약 \(minutes)분 뒤 도착 (\(stops))\(plate)"
    }

    public var currentFirstBusText: String {
        firstBusText(for: selectedBus)
    }

    public var currentSecondBusText: String {
        secondBusText(for: selectedBus)
    }

    public var currentStopName: String {
        selectedBus.stopName
    }

    public var currentDirectionHint: String {
        selectedBus.directionHint
    }

    public var lastUpdatedString: String {
        guard let lastUpdated = lastUpdated else { return "업데이트 안 됨" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: lastUpdated)
    }
}
