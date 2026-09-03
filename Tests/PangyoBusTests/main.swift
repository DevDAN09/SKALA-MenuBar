import Foundation
import PangyoBusKit

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
        },
        {
          "id": "B1002",
          "name": "602-1A",
          "busLineType": "MAUL",
          "arrival": {
            "arrivalTime": 300,
            "busStopCount": 3
          }
        },
        {
          "id": "B1003",
          "name": "602-1B (평일)",
          "busLineType": "MAUL",
          "arrival": {
            "arrivalTime": 90,
            "busStopCount": 1
          }
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(BusStopResponse.self, from: sampleJson)
    assert(response.name == "SK플래닛.판교디지털센터", "name should match")
    assert(response.lines.count == 3, "lines count should be 3")

    let line = response.lines.first!
    assert(line.name == "9007", "line name should be 9007")
    assert(line.arrival?.arrivalTime == 716, "arrival time should be 716")
    print("✅ testDecodeKakaoStopJson passed")
}

func testBusAPIServiceMultiBusFiltering() async throws {
    let json = """
    {
      "id": "BS73663",
      "name": "SK플래닛.판교디지털센터",
      "lines": [
        { "id": "B101", "name": "375", "arrival": { "arrivalTime": 200 } },
        { "id": "B102", "name": "9007", "arrival": { "arrivalTime": 650, "busStopCount": 7, "vehicleNumber": "경기70아6229" } },
        { "id": "B103", "name": "602-1A", "arrival": { "arrivalTime": 300, "busStopCount": 3, "vehicleNumber": "경기70아8021" } },
        { "id": "B104", "name": "602-1B (평일)", "arrival": { "arrivalTime": 80, "busStopCount": 1, "vehicleNumber": "경기70아8015" } }
      ]
    }
    """.data(using: .utf8)!

    let config = URLSessionConfiguration.ephemeral
    MockURLProtocol.stubResponseData = json
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)

    let service = BusAPIService(session: mockSession)
    let arrivals = try await service.fetchTargetBusesArrival(stopId: "BS73663")

    assert(arrivals[.bus9007]?.arrivalTime == 650, "9007 arrival time should be 650")
    assert(arrivals[.bus602_1A]?.arrivalTime == 300, "602-1A arrival time should be 300")
    assert(arrivals[.bus602_1B]?.arrivalTime == 80, "602-1B arrival time should be 80")
    print("✅ testBusAPIServiceMultiBusFiltering passed")
}

struct MockMultiService: BusAPIServiceProtocol, Sendable {
    let mockArrivals: [TargetBus: BusArrivalDetails]
    func fetchStop(stopId: String) async throws -> BusStopResponse {
        BusStopResponse(id: "BS73663", name: "SK플래닛", lines: [])
    }
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails? {
        mockArrivals[.bus9007]
    }
    func fetchTargetBusesArrival(stopId: String) async throws -> [TargetBus: BusArrivalDetails] {
        mockArrivals
    }
}

@MainActor
func testBusViewModelSelection() async {
    let arrivals: [TargetBus: BusArrivalDetails] = [
        .bus9007: BusArrivalDetails(arrivalTime: 720, busStopCount: 8),
        .bus602_1A: BusArrivalDetails(arrivalTime: 300, busStopCount: 3),
        .bus602_1B: BusArrivalDetails(arrivalTime: 90, busStopCount: 1)
    ]
    let vm = BusViewModel(apiService: MockMultiService(mockArrivals: arrivals))
    vm.stopAutoRefresh()

    vm.selectedBus = .bus9007
    await vm.refresh()
    assert(vm.menuTitle == "🚌 9007: 12분 (8전)", "Title should be '🚌 9007: 12분 (8전)', got '\(vm.menuTitle)'")

    vm.selectedBus = .bus602_1B
    assert(vm.menuTitle == "🚨 602-1B: 2분 전 (1전)", "Title should be '🚨 602-1B: 2분 전 (1전)', got '\(vm.menuTitle)'")

    vm.selectedBus = .bus602_1A
    assert(vm.menuTitle == "🚌 602-1A: 5분 (3전)", "Title should be '🚌 602-1A: 5분 (3전)', got '\(vm.menuTitle)'")

    print("✅ testBusViewModelSelection passed")
}

func main() async {
    do {
        try testDecodeKakaoStopJson()
        try await testBusAPIServiceMultiBusFiltering()
        await testBusViewModelSelection()
        print("🎉 All multi-bus tests passed successfully!")
    } catch {
        print("❌ Test failed: \(error)")
        exit(1)
    }
}

await main()
