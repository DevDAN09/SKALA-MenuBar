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
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(BusStopResponse.self, from: sampleJson)
    assert(response.name == "SK플래닛.판교디지털센터", "name should match")
    assert(response.lines.count == 1, "lines count should be 1")

    let line = response.lines.first!
    assert(line.name == "9007", "line name should be 9007")
    assert(line.arrival?.arrivalTime == 716, "arrival time should be 716")
    assert(line.arrival?.busStopCount == 8, "bus stop count should be 8")
    assert(line.arrival?.vehicleNumber == "경기70아6229", "vehicle number should match")
    print("✅ testDecodeKakaoStopJson passed")
}

func testBusAPIServiceFiltering() async throws {
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

    assert(arrival != nil, "arrival must not be nil")
    assert(arrival?.arrivalTime == 650, "arrival time should be 650")
    assert(arrival?.busStopCount == 7, "bus stop count should be 7")
    assert(arrival?.vehicleNumber == "경기70아6229", "vehicle plate must match")
    print("✅ testBusAPIServiceFiltering passed")
}

struct MockService: BusAPIServiceProtocol, Sendable {
    let mockArrival: BusArrivalDetails?
    func fetchStop(stopId: String) async throws -> BusStopResponse {
        BusStopResponse(id: "BS73663", name: "SK플래닛", lines: [])
    }
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails? {
        mockArrival
    }
}

@MainActor
func testBusViewModelFormatting() async {
    let arrivalNormal = BusArrivalDetails(
        direction: "서울역 방면",
        vehicleNumber: "경기70아6229",
        arrivalTime: 720, // 12 mins
        busStopCount: 8
    )
    let vmNormal = BusViewModel(apiService: MockService(mockArrival: arrivalNormal))
    vmNormal.stopAutoRefresh()
    await vmNormal.refresh()
    assert(vmNormal.menuTitle == "🚌 9007: 12분 (8전)", "Title should be '🚌 9007: 12분 (8전)', got '\(vmNormal.menuTitle)'")

    let arrivalSoon = BusArrivalDetails(
        direction: "서울역 방면",
        vehicleNumber: "경기70아6229",
        arrivalTime: 110, // 2 mins
        busStopCount: 1
    )
    let vmSoon = BusViewModel(apiService: MockService(mockArrival: arrivalSoon))
    vmSoon.stopAutoRefresh()
    await vmSoon.refresh()
    assert(vmSoon.menuTitle == "🚨 9007: 2분 전 (1전)", "Title should be '🚨 9007: 2분 전 (1전)', got '\(vmSoon.menuTitle)'")

    let arrivalNone = BusArrivalDetails(arrivalTime: 0, busStopCount: 0)
    let vmNone = BusViewModel(apiService: MockService(mockArrival: arrivalNone))
    vmNone.stopAutoRefresh()
    await vmNone.refresh()
    assert(vmNone.menuTitle == "🚌 9007: 정보 없음", "Title should be '🚌 9007: 정보 없음', got '\(vmNone.menuTitle)'")

    print("✅ testBusViewModelFormatting passed")
}

func main() async {
    do {
        try testDecodeKakaoStopJson()
        try await testBusAPIServiceFiltering()
        await testBusViewModelFormatting()
        print("🎉 All Task 1, 2, 3 tests passed successfully!")
    } catch {
        print("❌ Test failed: \(error)")
        exit(1)
    }
}

await main()
