import Foundation
import SKALAMenuBarKit

final class MockURLProtocol: URLProtocol {
    static var stopDataMap: [String: Data] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let urlStr = request.url?.absoluteString ?? ""
        var matchedData: Data?

        for (stopId, data) in MockURLProtocol.stopDataMap {
            if urlStr.contains(stopId) {
                matchedData = data
                break
            }
        }

        if let data = matchedData {
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

func testTargetBusStopMapping() {
    assert(TargetBus.bus9007.stopId == "BS73663", "9007 should map to BS73663")
    assert(TargetBus.bus9007.stopName == "SK플래닛·판교디지털센터", "9007 stopName should be SK플래닛·판교디지털센터")

    assert(TargetBus.bus602_1A.stopId == "BS73662", "602-1A should map to BS73662 (이노밸리)")
    assert(TargetBus.bus602_1A.stopName == "이노밸리·포스코DX", "602-1A stopName should be 이노밸리·포스코DX")

    assert(TargetBus.bus602_1B.stopId == "BS73662", "602-1B should map to BS73662 (이노밸리)")
    assert(TargetBus.bus602_1B.stopName == "이노밸리·포스코DX", "602-1B stopName should be 이노밸리·포스코DX")
    print("✅ testTargetBusStopMapping passed")
}

func testBusAPIServiceMultiStopConcurrent() async throws {
    let jsonPlanet = """
    {
      "id": "BS73663",
      "name": "SK플래닛.판교디지털센터",
      "lines": [
        { "id": "B102", "name": "9007", "arrival": { "arrivalTime": 650, "busStopCount": 7, "vehicleNumber": "경기70아6229" } }
      ]
    }
    """.data(using: .utf8)!

    let jsonInnoval = """
    {
      "id": "BS73662",
      "name": "이노밸리.포스코DX",
      "lines": [
        { "id": "B103", "name": "602-1A", "arrival": { "arrivalTime": 330, "busStopCount": 3, "vehicleNumber": "경기70아8021" } },
        { "id": "B104", "name": "602-1B (평일)", "arrival": { "arrivalTime": 95, "busStopCount": 1, "vehicleNumber": "경기70아6276" } }
      ]
    }
    """.data(using: .utf8)!

    MockURLProtocol.stopDataMap = [
        "BS73663": jsonPlanet,
        "BS73662": jsonInnoval
    ]

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)

    let service = BusAPIService(session: mockSession)
    let arrivals = try await service.fetchTargetBusesArrival()

    assert(arrivals[.bus9007]?.arrivalTime == 650, "9007 arrival time should be 650")
    assert(arrivals[.bus602_1A]?.arrivalTime == 330, "602-1A arrival time should be 330")
    assert(arrivals[.bus602_1B]?.arrivalTime == 95, "602-1B arrival time should be 95")
    print("✅ testBusAPIServiceMultiStopConcurrent passed")
}

struct MockMultiService: BusAPIServiceProtocol, Sendable {
    let mockArrivals: [TargetBus: BusArrivalDetails]
    func fetchStop(stopId: String) async throws -> BusStopResponse {
        BusStopResponse(id: stopId, name: "정류장", lines: [])
    }
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails? {
        mockArrivals[.bus9007]
    }
    func fetchTargetBusesArrival() async throws -> [TargetBus: BusArrivalDetails] {
        mockArrivals
    }
}

@MainActor
func testBusViewModelDynamicStopName() async {
    let arrivals: [TargetBus: BusArrivalDetails] = [
        .bus9007: BusArrivalDetails(arrivalTime: 720, busStopCount: 8),
        .bus602_1A: BusArrivalDetails(arrivalTime: 300, busStopCount: 3),
        .bus602_1B: BusArrivalDetails(arrivalTime: 90, busStopCount: 1)
    ]
    let vm = BusViewModel(apiService: MockMultiService(mockArrivals: arrivals))
    vm.stopAutoRefresh()

    vm.selectedBus = .bus9007
    await vm.refresh()
    assert(vm.currentStopName == "SK플래닛·판교디지털센터", "9007 stopName mismatch")
    assert(vm.menuTitle == "🚌 9007: 12분 (8전)", "9007 menuTitle mismatch")

    vm.selectedBus = .bus602_1A
    assert(vm.currentStopName == "이노밸리·포스코DX", "602-1A stopName mismatch")
    assert(vm.menuTitle == "🚌 602-1A: 5분 (3전)", "602-1A menuTitle mismatch")

    vm.selectedBus = .bus602_1B
    assert(vm.currentStopName == "이노밸리·포스코DX", "602-1B stopName mismatch")
    assert(vm.menuTitle == "🚨 602-1B: 2분 전 (1전)", "602-1B menuTitle mismatch")

    print("✅ testBusViewModelDynamicStopName passed")
}

func testCafeteriaMenuModels() {
    let dummyDay = DailyMenu(
        weekday: "화",
        dateString: "2026-09-08",
        breakfast: [MealCategoryItem(cornerName: "한식", items: ["쌀밥", "된장국"])],
        lunch: [
            MealCategoryItem(cornerName: "한식", items: ["흑미밥", "제육볶음"]),
            MealCategoryItem(cornerName: "양식", items: ["돈까스"])
        ],
        dinner: [MealCategoryItem(cornerName: "한식", items: ["볶음밥"])]
    )

    let dummyWeekly = WeeklyMenu(
        title: "이노밸리 식단표",
        imageUrl: "https://example.com/img.jpg",
        postUrl: "https://pf.kakao.com/_LCxlxlxb",
        days: [dummyDay]
    )

    assert(dummyWeekly.menu(for: "화")?.lunch.count == 2, "Lunch should have 2 categories")
    assert(dummyDay.meals(for: .lunch).first?.items.contains("제육볶음") == true, "Lunch items mismatch")
    print("✅ testCafeteriaMenuModels passed")
}

@MainActor
func testCafeteriaViewModelDefaults() {
    let vm = CafeteriaViewModel()
    assert(["월", "화", "수", "목", "금"].contains(vm.selectedWeekday), "Default weekday should be valid")
    assert(MealType.allCases.contains(vm.selectedMealType), "Default meal type should be valid")
    print("✅ testCafeteriaViewModelDefaults passed")
}

func testCafeteriaLiveFetchAndParse() async throws {
    let service = CafeteriaAPIService()
    let menu = try await service.fetchWeeklyMenu(forceRefresh: true)
    assert(!menu.days.isEmpty, "Days should not be empty")
    assert(menu.days.count == 5, "Should parse 5 weekdays (월~금)")

    for day in ["월", "화", "수", "목", "금"] {
        if let d = menu.menu(for: day) {
            print("🍱 [\(day)요일] 점심 코너 수: \(d.lunch.count)")
            for cat in d.lunch {
                print("   [\(cat.cornerName)] \(cat.items.joined(separator: ", "))")
            }
            assert(!d.lunch.isEmpty, "\(day) lunch should have items")
        }
    }

    print("✅ testCafeteriaLiveFetchAndParse passed")
}

func main() async {
    do {
        testTargetBusStopMapping()
        try await testBusAPIServiceMultiStopConcurrent()
        await testBusViewModelDynamicStopName()
        testCafeteriaMenuModels()
        await testCafeteriaViewModelDefaults()
        try await testCafeteriaLiveFetchAndParse()
        print("🎉 All PangyoBus & Cafeteria tests passed successfully!")
    } catch {
        print("❌ Test failed: \(error)")
        exit(1)
    }
}

await main()

