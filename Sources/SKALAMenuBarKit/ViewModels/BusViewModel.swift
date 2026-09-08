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

    private let apiService: BusAPIService
    private var timer: Timer?

    public init(apiService: BusAPIService = BusAPIService(), refreshInterval: Int = 30) {
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
            self.menuTitle = "⚠️ \(selectedBus.rawValue): 확인 실패"
        }
        isLoading = false
    }

    public func formatMenuTitle(_ details: BusArrivalDetails?) -> String {
        let busName = selectedBus.rawValue
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
        arrivalLine(
            seconds: allArrivals[bus]?.arrivalTime,
            stopCount: allArrivals[bus]?.busStopCount,
            plate: allArrivals[bus]?.vehicleNumber,
            empty: "도착 정보 없음 (차고지 대기 또는 운행 종료)"
        )
    }

    public func secondBusText(for bus: TargetBus) -> String {
        arrivalLine(
            seconds: allArrivals[bus]?.arrivalTime2,
            stopCount: allArrivals[bus]?.busStopCount2,
            plate: allArrivals[bus]?.vehicleNumber2,
            empty: "다음 버스 도착 정보 없음"
        )
    }

    public var lastUpdatedString: String {
        guard let lastUpdated else { return "업데이트 안 됨" }
        return lastUpdated.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
    }

    private func arrivalLine(seconds: Int?, stopCount: Int?, plate: String?, empty: String) -> String {
        guard let seconds, seconds > 0 else { return empty }
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = stopCount.map { "\($0)정류장 전" } ?? ""
        let plateText = plate.map { " [\($0)]" } ?? ""
        return "약 \(minutes)분 뒤 도착 (\(stops))\(plateText)"
    }
}
