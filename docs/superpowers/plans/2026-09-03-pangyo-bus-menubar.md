# Pangyo 9007 Bus Menubar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS menu bar application (`pangyo-bus-menubar`) that displays real-time arrival minutes for bus 9007 at the SK Planet / Pangyo Digital Center stop (towards Seoul Station).

**Architecture:** A standalone Swift Package Manager (SPM) application for macOS 13+ with zero external third-party dependencies. It polls Kakao Map's public stop endpoint (`BS73663`), extracts 9007 bus arrival predictions (seconds remaining, stops remaining, vehicle plate), formats the status title in the menu bar (`🚌 9007: X분 (Y전)`), and provides a rich drop-down menu with detailed cards and manual refresh controls.

**Tech Stack:** Swift 5.9+, macOS 13.0+, SwiftUI (`MenuBarExtra`), AppKit (`NSApplication.setActivationPolicy(.accessory)`), Foundation (`URLSession`, `JSONDecoder`), XCTest.

**Spec:**
- Target Directory: `/Users/yeongmin-yun/2026/pangyo-bus-menubar`
- Stop ID: `BS73663` (SK플래닛·판교디지털센터, 다음 정류장 유라코퍼레이션·SK케미칼 / 서울역 방면)
- Bus Line: `9007`
- Endpoint: `https://map.kakao.com/bus/stop.json?busstopid=BS73663` (HTTP GET with `User-Agent: Mozilla/5.0`)

## Global Constraints

- Standalone executable in `/Users/yeongmin-yun/2026/pangyo-bus-menubar`
- macOS 13.0 deployment target minimum
- Zero external package dependencies (Apple SDK standard library only)
- Accessory mode (no Dock icon, menu bar only)

---

### Task 1: Package Scaffolding & Data Model

**Files:**
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Package.swift`
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/Models/BusArrival.swift`
- Test: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusArrivalModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct BusStopResponse: Codable {
      public let id: String
      public let name: String
      public let lines: [BusLine]
  }

  public struct BusLine: Codable {
      public let id: String
      public let name: String
      public let busLineType: String?
      public let arrival: BusArrivalDetails?
  }

  public struct BusArrivalDetails: Codable {
      public let direction: String?
      public let nextBusStopName: String?
      public let vehicleNumber: String?
      public let arrivalTime: Int? // seconds
      public let busStopCount: Int?
      public let vehicleNumber2: String?
      public let arrivalTime2: Int? // seconds
      public let busStopCount2: Int?
  }
  ```

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PangyoBus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PangyoBus", targets: ["PangyoBus"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PangyoBus",
            dependencies: [],
            path: "Sources/PangyoBus"
        ),
        .testTarget(
            name: "PangyoBusTests",
            dependencies: ["PangyoBus"],
            path: "Tests/PangyoBusTests"
        )
    ]
)
```

- [ ] **Step 2: Write failing unit test for `BusArrival` decoding**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusArrivalModelTests.swift`:
```swift
import XCTest
@testable import PangyoBus

final class BusArrivalModelTests: XCTestCase {
    func testDecodeKakaoStopJson() throws {
        let sampleJson = """
        {
          "id": "BS73663",
          "name": "SK플래닛.판교디지털센터",
          "lines": [
            {
              "id": "B1001",
              "name": "9007",
              "busLineType": "DIRECT",
              "arrival": {
                "direction": "유라코퍼레이션.SK케미칼 방향",
                "nextBusStopName": "유라코퍼레이션.SK케미칼",
                "vehicleNumber": "경기70아6229",
                "arrivalTime": 716,
                "busStopCount": 8,
                "vehicleNumber2": "경기70아1234",
                "arrivalTime2": 1500,
                "busStopCount2": 15
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(BusStopResponse.self, from: sampleJson)
        XCTAssertEqual(response.name, "SK플래닛.판교디지털센터")
        XCTAssertEqual(response.lines.count, 1)

        let line = response.lines.first!
        XCTAssertEqual(line.name, "9007")
        XCTAssertEqual(line.arrival?.arrivalTime, 716)
        XCTAssertEqual(line.arrival?.busStopCount, 8)
        XCTAssertEqual(line.arrival?.vehicleNumber, "경기70아6229")
    }
}
```

- [ ] **Step 3: Run test to verify it fails (compiler failure because types do not exist yet)**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: FAIL (`Cannot find 'BusStopResponse' in scope`)

- [ ] **Step 4: Implement minimal model in `Sources/PangyoBus/Models/BusArrival.swift`**

```swift
import Foundation

public struct BusStopResponse: Codable {
    public let id: String
    public let name: String
    public let lines: [BusLine]

    public init(id: String, name: String, lines: [BusLine]) {
        self.id = id
        self.name = name
        self.lines = lines
    }
}

public struct BusLine: Codable {
    public let id: String
    public let name: String
    public let busLineType: String?
    public let arrival: BusArrivalDetails?

    public init(id: String, name: String, busLineType: String? = nil, arrival: BusArrivalDetails? = nil) {
        self.id = id
        self.name = name
        self.busLineType = busLineType
        self.arrival = arrival
    }
}

public struct BusArrivalDetails: Codable {
    public let direction: String?
    public let nextBusStopName: String?
    public let vehicleNumber: String?
    public let arrivalTime: Int?
    public let busStopCount: Int?
    public let vehicleNumber2: String?
    public let arrivalTime2: Int?
    public let busStopCount2: Int?

    public init(
        direction: String? = nil,
        nextBusStopName: String? = nil,
        vehicleNumber: String? = nil,
        arrivalTime: Int? = nil,
        busStopCount: Int? = nil,
        vehicleNumber2: String? = nil,
        arrivalTime2: Int? = nil,
        busStopCount2: Int? = nil
    ) {
        self.direction = direction
        self.nextBusStopName = nextBusStopName
        self.vehicleNumber = vehicleNumber
        self.arrivalTime = arrivalTime
        self.busStopCount = busStopCount
        self.vehicleNumber2 = vehicleNumber2
        self.arrivalTime2 = arrivalTime2
        self.busStopCount2 = busStopCount2
    }
}
```

- [ ] **Step 5: Run tests and verify PASS**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: PASS

- [ ] **Step 6: Initialize git repo in `/Users/yeongmin-yun/2026/pangyo-bus-menubar` and commit**

```bash
git init
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold SPM project and BusArrival model"
```

---

### Task 2: BusAPIService & Live Data Fetching

**Files:**
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/Services/BusAPIService.swift`
- Test: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusAPIServiceTests.swift`

**Interfaces:**
- Consumes: `BusStopResponse`, `BusLine`, `BusArrivalDetails`
- Produces:
  ```swift
  public protocol BusAPIServiceProtocol: Sendable {
      func fetchStop(stopId: String) async throws -> BusStopResponse
      func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails?
  }

  public final class BusAPIService: BusAPIServiceProtocol {
      public static let shared = BusAPIService()
      public init(session: URLSession = .shared)
      public func fetchStop(stopId: String) async throws -> BusStopResponse
      public func fetch9007Arrival(stopId: String = "BS73663") async throws -> BusArrivalDetails?
  }
  ```

- [ ] **Step 1: Write unit test for `BusAPIService` using mock URLProtocol**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusAPIServiceTests.swift`:
```swift
import XCTest
@testable import PangyoBus

final class BusAPIServiceTests: XCTestCase {
    func testFetch9007ArrivalFiltersCorrectLine() async throws {
        let json = """
        {
          "id": "BS73663",
          "name": "SK플래닛.판교디지털센터",
          "lines": [
            { "id": "B101", "name": "375", "arrival": { "arrivalTime": 200 } },
            { "id": "B102", "name": "9007", "arrival": { "arrivalTime": 650, "busStopCount": 7, "vehicleNumber": "경기70아6229" } }
          ]
        }
        """.data(using: .utf8)!

        let config = URLSessionConfiguration.ephemeral
        MockURLProtocol.stubResponseData = json
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let service = BusAPIService(session: mockSession)
        let arrival = try await service.fetch9007Arrival(stopId: "BS73663")

        XCTAssertNotNil(arrival)
        XCTAssertEqual(arrival?.arrivalTime, 650)
        XCTAssertEqual(arrival?.busStopCount, 7)
        XCTAssertEqual(arrival?.vehicleNumber, "경기70아6229")
    }
}

final class MockURLProtocol: URLProtocol {
    static var stubResponseData: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let data = MockURLProtocol.stubResponseData {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: FAIL (`Cannot find 'BusAPIService' in scope`)

- [ ] **Step 3: Implement `BusAPIService`**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/Services/BusAPIService.swift`:
```swift
import Foundation

public protocol BusAPIServiceProtocol: Sendable {
    func fetchStop(stopId: String) async throws -> BusStopResponse
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails?
}

public final class BusAPIService: BusAPIServiceProtocol, @unchecked Sendable {
    public static let shared = BusAPIService()
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchStop(stopId: String) async throws -> BusStopResponse {
        guard let url = URL(string: "https://map.kakao.com/bus/stop.json?busstopid=\(stopId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(BusStopResponse.self, from: data)
    }

    public func fetch9007Arrival(stopId: String = "BS73663") async throws -> BusArrivalDetails? {
        let stopInfo = try await fetchStop(stopId: stopId)
        guard let line9007 = stopInfo.lines.first(where: { $0.name.trimmingCharacters(in: .whitespaces) == "9007" }) else {
            return nil
        }
        return line9007.arrival
    }
}
```

- [ ] **Step 4: Run tests to verify PASS**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ Tests/
git commit -m "feat: implement BusAPIService with Kakao Map endpoint integration"
```

---

### Task 3: BusViewModel with Status Formatting & Timer

**Files:**
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/ViewModels/BusViewModel.swift`
- Test: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusViewModelTests.swift`

**Interfaces:**
- Consumes: `BusAPIServiceProtocol`, `BusArrivalDetails`
- Produces:
  ```swift
  @MainActor
  public final class BusViewModel: ObservableObject {
      @Published public private(set) var menuTitle: String
      @Published public private(set) var arrival: BusArrivalDetails?
      @Published public private(set) var lastUpdated: Date?
      @Published public private(set) var isLoading: Bool
      @Published public private(set) var errorMessage: String?
      @Published public var refreshIntervalSeconds: Int

      public init(apiService: BusAPIServiceProtocol = BusAPIService.shared, refreshInterval: Int = 30)
      public func refresh() async
      public func startAutoRefresh()
      public func stopAutoRefresh()
  }
  ```

- [ ] **Step 1: Write unit test for string formatting and countdown logic**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Tests/PangyoBusTests/BusViewModelTests.swift`:
```swift
import XCTest
@testable import PangyoBus

@MainActor
final class BusViewModelTests: XCTestCase {
    struct MockService: BusAPIServiceProtocol {
        let mockArrival: BusArrivalDetails?
        func fetchStop(stopId: String) async throws -> BusStopResponse {
            BusStopResponse(id: "BS73663", name: "SK플래닛", lines: [])
        }
        func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails? {
            mockArrival
        }
    }

    func testMenuTitleWithNormalArrival() async {
        let arrival = BusArrivalDetails(
            direction: "서울역 방면",
            vehicleNumber: "경기70아6229",
            arrivalTime: 720, // 12 mins
            busStopCount: 8
        )
        let vm = BusViewModel(apiService: MockService(mockArrival: arrival))
        await vm.refresh()

        XCTAssertEqual(vm.menuTitle, "🚌 9007: 12분 (8전)")
    }

    func testMenuTitleWithSoonArrival() async {
        let arrival = BusArrivalDetails(
            direction: "서울역 방면",
            vehicleNumber: "경기70아6229",
            arrivalTime: 110, // < 2 mins (soon)
            busStopCount: 1
        )
        let vm = BusViewModel(apiService: MockService(mockArrival: arrival))
        await vm.refresh()

        XCTAssertEqual(vm.menuTitle, "🚨 9007: 2분 전 (1전)")
    }

    func testMenuTitleWithNoArrival() async {
        let arrival = BusArrivalDetails(arrivalTime: 0, busStopCount: 0)
        let vm = BusViewModel(apiService: MockService(mockArrival: arrival))
        await vm.refresh()

        XCTAssertEqual(vm.menuTitle, "🚌 9007: 정보 없음")
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: FAIL (`Cannot find 'BusViewModel' in scope`)

- [ ] **Step 3: Implement `BusViewModel`**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/ViewModels/BusViewModel.swift`:
```swift
import Foundation
import Combine

@MainActor
public final class BusViewModel: ObservableObject {
    @Published public private(set) var menuTitle: String = "🚌 9007: 로딩 중…"
    @Published public private(set) var arrival: BusArrivalDetails?
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
            let details = try await apiService.fetch9007Arrival(stopId: "BS73663")
            self.arrival = details
            self.lastUpdated = Date()
            self.menuTitle = formatMenuTitle(details)
        } catch {
            self.errorMessage = error.localizedDescription
            self.menuTitle = "⚠️ 9007: 확인 실패"
        }
        isLoading = false
    }

    private func formatMenuTitle(_ details: BusArrivalDetails?) -> String {
        guard let details = details, let seconds = details.arrivalTime, seconds > 0 else {
            return "🚌 9007: 정보 없음"
        }

        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = details.busStopCount ?? 0

        if minutes <= 3 {
            return "🚨 9007: \(minutes)분 전 (\(stops)전)"
        } else {
            return "🚌 9007: \(minutes)분 (\(stops)전)"
        }
    }

    public var firstBusText: String {
        guard let arrival = arrival, let seconds = arrival.arrivalTime, seconds > 0 else {
            return "도착 정보 없음 (차고지 대기 또는 운행 종료)"
        }
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = arrival.busStopCount.map { "\($0)정류장 전" } ?? ""
        let plate = arrival.vehicleNumber ?? ""
        return "약 \(minutes)분 뒤 도착 (\(stops)) [\(plate)]"
    }

    public var secondBusText: String {
        guard let arrival = arrival, let seconds = arrival.arrivalTime2, seconds > 0 else {
            return "다음 버스 도착 정보 없음"
        }
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        let stops = arrival.busStopCount2.map { "\($0)정류장 전" } ?? ""
        let plate = arrival.vehicleNumber2 ?? ""
        return "약 \(minutes)분 뒤 도착 (\(stops)) [\(plate)]"
    }

    public var lastUpdatedString: String {
        guard let lastUpdated = lastUpdated else { return "업데이트 안 됨" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: lastUpdated)
    }
}
```

- [ ] **Step 4: Run tests to verify PASS**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ Tests/
git commit -m "feat: implement BusViewModel with live countdown and title formatting"
```

---

### Task 4: SwiftUI MenuBar UI & Main App Entrypoint

**Files:**
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/Views/BusStatusMenuView.swift`
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/main.swift`

- [ ] **Step 1: Implement `BusStatusMenuView.swift`**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/Views/BusStatusMenuView.swift`:
```swift
import SwiftUI

public struct BusStatusMenuView: View {
    @ObservedObject var viewModel: BusViewModel

    public init(viewModel: BusViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SK플래닛·판교디지털센터")
                        .font(.headline)
                    Text("서울역/고속터미널 방면 · 9007번")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Divider()

            // 1st Bus Card
            VStack(alignment: .leading, spacing: 4) {
                Label("첫 번째 버스", systemImage: "bus.fill")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Text(viewModel.firstBusText)
                    .font(.system(.body, design: .rounded))
                    .bold()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // 2nd Bus Card
            VStack(alignment: .leading, spacing: 4) {
                Label("두 번째 버스", systemImage: "bus")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(viewModel.secondBusText)
                    .font(.system(.body, design: .rounded))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)

            if let error = viewModel.errorMessage {
                Text("오류: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            // Controls & Footer
            HStack {
                Text("마지막 갱신: \(viewModel.lastUpdatedString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("지금 갱신") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // Interval selector & Quit
            HStack {
                Picker("갱신 주기", selection: $viewModel.refreshIntervalSeconds) {
                    Text("15초").tag(15)
                    Text("30초").tag(30)
                    Text("60초").tag(60)
                }
                .pickerStyle(.menu)

                Spacer()

                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
```

- [ ] **Step 2: Implement `main.swift`**

Create `/Users/yeongmin-yun/2026/pangyo-bus-menubar/Sources/PangyoBus/main.swift`:
```swift
import SwiftUI
import AppKit

@main
struct PangyoBusApp: App {
    @StateObject private var viewModel = BusViewModel()

    init() {
        // Run as accessory app (no Dock icon, stays in menu bar only)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            BusStatusMenuView(viewModel: viewModel)
                .task {
                    await viewModel.refresh()
                }
        } label: {
            Text(viewModel.menuTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Run `swift build` to verify clean compilation**

Run: `swift build --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
Expected: Build complete!

- [ ] **Step 4: Commit**

```bash
git add Sources/
git commit -m "feat: implement SwiftUI MenuBarExtra UI and application entry point"
```

---

### Task 5: Live Verification & Convenience Runner Script

**Files:**
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/scripts/run.sh`
- Create: `/Users/yeongmin-yun/2026/pangyo-bus-menubar/README.md`

- [ ] **Step 1: Create convenience runner script `scripts/run.sh`**

```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/.."
echo "Building PangyoBus..."
swift build -c release
echo "Running PangyoBus in background..."
.build/release/PangyoBus &
echo "PangyoBus is now running in your menu bar!"
```

- [ ] **Step 2: Create `README.md` with usage instructions**

- [ ] **Step 3: Make `run.sh` executable and run live test to verify live data fetch**

Run: `swift test --package-path /Users/yeongmin-yun/2026/pangyo-bus-menubar`
And run a 3-second live smoke test of the binary or verify via swift command.

- [ ] **Step 4: Final commit**

```bash
git add scripts/ README.md
git commit -m "docs: add runner script and README"
```
