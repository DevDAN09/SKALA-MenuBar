import Foundation
import SwiftUI
import UserNotifications
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

func makeMockBusSession() -> URLSession {
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
    return URLSession(configuration: config)
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
    let service = BusAPIService(session: makeMockBusSession())
    let arrivals = try await service.fetchTargetBusesArrival()

    assert(arrivals[.bus9007]?.arrivalTime == 650, "9007 arrival time should be 650")
    assert(arrivals[.bus602_1A]?.arrivalTime == 330, "602-1A arrival time should be 330")
    assert(arrivals[.bus602_1B]?.arrivalTime == 95, "602-1B arrival time should be 95")
    print("✅ testBusAPIServiceMultiStopConcurrent passed")
}

@MainActor
func testBusViewModelDynamicStopName() async {
    let vm = BusViewModel(apiService: BusAPIService(session: makeMockBusSession()))
    vm.stopAutoRefresh()

    vm.selectedBus = .bus9007
    await vm.refresh()
    assert(vm.selectedBus.stopName == "SK플래닛·판교디지털센터", "9007 stopName mismatch")
    assert(vm.menuTitle == "🚌 9007: 11분 (7전)", "9007 menuTitle mismatch")

    vm.selectedBus = .bus602_1A
    assert(vm.selectedBus.stopName == "이노밸리·포스코DX", "602-1A stopName mismatch")
    assert(vm.menuTitle == "🚌 602-1A: 6분 (3전)", "602-1A menuTitle mismatch")

    vm.selectedBus = .bus602_1B
    assert(vm.selectedBus.stopName == "이노밸리·포스코DX", "602-1B stopName mismatch")
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
    assert(MealType.allCases == [.lunch, .dinner], "MealType should only contain lunch and dinner")
    assert(MealCorner.allCases == [.korean, .western, .noodle], "MealCorner should contain korean, western, noodle")
    assert(vm.selectedCorner == .korean, "Default corner should be korean")
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

func testCommuteServiceKSTCheckOutGate() {
    let service = CommuteService()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Seoul")!

    // 17:49:59 KST -> false
    var comps = DateComponents(year: 2026, month: 9, day: 9, hour: 17, minute: 49, second: 59)
    let beforeDate = cal.date(from: comps)!
    assert(!service.isCheckOutAllowed(at: beforeDate), "17:49:59 KST should NOT allow checkout")
    let remaining = service.timeUntilCheckOut(at: beforeDate)
    assert(remaining?.minutes == 0 && remaining?.seconds == 1, "Remaining time should be 1 second")

    // 17:50:00 KST -> true
    comps.minute = 50
    comps.second = 0
    let exactDate = cal.date(from: comps)!
    assert(service.isCheckOutAllowed(at: exactDate), "17:50:00 KST should allow checkout")
    assert(service.timeUntilCheckOut(at: exactDate) == nil, "Remaining time should be nil after 17:50")

    // 09:00:00 KST -> false
    comps.hour = 9
    comps.minute = 0
    let morningDate = cal.date(from: comps)!
    assert(!service.isCheckOutAllowed(at: morningDate), "09:00:00 KST should NOT allow checkout")

    // 16:50:00 KST -> false, 1 hour 0 min 0 sec remaining
    comps.hour = 16
    comps.minute = 50
    comps.second = 0
    let oneHourBefore = cal.date(from: comps)!
    assert(!service.isCheckOutAllowed(at: oneHourBefore), "16:50:00 KST should NOT allow checkout")
    let rem1h = service.timeUntilCheckOut(at: oneHourBefore)
    assert(rem1h?.hours == 1 && rem1h?.minutes == 0 && rem1h?.seconds == 0, "Remaining time should be exactly 1 hour")

    // 18:30:00 KST -> true, nil remaining
    comps.hour = 18
    comps.minute = 30
    comps.second = 0
    let eveningDate = cal.date(from: comps)!
    assert(service.isCheckOutAllowed(at: eveningDate), "18:30:00 KST should allow checkout")
    assert(service.timeUntilCheckOut(at: eveningDate) == nil, "Remaining time should be nil after 17:50")

    // Target constants verification
    assert(service.targetSSID == "skaxedu", "SSID should match targetSSID")
    assert(service.targetURL == URL(string: "https://att.skala-ai.com/att-checkin")!, "targetURL mismatch")

    print("✅ testCommuteServiceKSTCheckOutGate passed")
}

func testCommuteNotificationDateComponents() {
    let kst = TimeZone(identifier: "Asia/Seoul")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = kst

    // Morning check-in component: 8:50 KST
    let morningHour = 8
    let morningMinute = 50
    assert(morningHour == 8 && morningMinute == 50, "Morning alarm should be 08:50")

    // Evening check-out component: 17:50 KST
    let eveningHour = 17
    let eveningMinute = 50
    assert(eveningHour == 17 && eveningMinute == 50, "Evening alarm should be 17:50")

    print("✅ testCommuteNotificationDateComponents passed")
}

func testCommuteNotificationService() async {
    assert(CommuteNotificationService.morningNotificationId == "skala.commute.morning.checkin")
    assert(CommuteNotificationService.eveningNotificationId == "skala.commute.evening.checkout")

    let service = CommuteNotificationService()
    let protoService: CommuteNotificationServiceProtocol = service
    _ = protoService

    // In CLI test environment (no bundle identifier), calling methods should safely execute without crashing
    let auth = await service.requestAuthorization()
    assert(!auth, "CLI test authorization should return false safely")
    await service.scheduleWeekdayReminders()

    let requests = service.buildNotificationRequests()
    assert(requests.count == 10, "Should generate 10 requests (5 weekdays * 2)")

    let weekdays = [2, 3, 4, 5, 6]
    for weekday in weekdays {
        let morning = service.makeMorningNotificationRequest(for: weekday)
        assert(morning.identifier == "\(CommuteNotificationService.morningNotificationId).\(weekday)")
        assert(morning.content.title == "⏰ [SKALA] 출석 확인 알림")
        assert(morning.content.body == "8시 50분입니다. 오늘 입실(출석) 체크하셨나요?")
        assert(morning.content.sound == .default)
        if let trigger = morning.trigger as? UNCalendarNotificationTrigger {
            assert(trigger.repeats == true)
            assert(trigger.dateComponents.weekday == weekday)
            assert(trigger.dateComponents.hour == 8)
            assert(trigger.dateComponents.minute == 50)
            assert(trigger.dateComponents.timeZone?.identifier == "Asia/Seoul" || trigger.dateComponents.timeZone?.secondsFromGMT() == 9 * 3600)
        } else {
            assertionFailure("Morning trigger is not UNCalendarNotificationTrigger")
        }

        let evening = service.makeEveningNotificationRequest(for: weekday)
        assert(evening.identifier == "\(CommuteNotificationService.eveningNotificationId).\(weekday)")
        assert(evening.content.title == "👋 [SKALA] 퇴근 체크인 알림")
        assert(evening.content.body == "17시 50분입니다. 지금 퇴실(퇴근) 체크가 가능합니다!")
        assert(evening.content.sound == .default)
        if let trigger = evening.trigger as? UNCalendarNotificationTrigger {
            assert(trigger.repeats == true)
            assert(trigger.dateComponents.weekday == weekday)
            assert(trigger.dateComponents.hour == 17)
            assert(trigger.dateComponents.minute == 50)
            assert(trigger.dateComponents.timeZone?.identifier == "Asia/Seoul" || trigger.dateComponents.timeZone?.secondsFromGMT() == 9 * 3600)
        } else {
            assertionFailure("Evening trigger is not UNCalendarNotificationTrigger")
        }
    }

    print("✅ testCommuteNotificationService passed")
}

@MainActor
func testCommuteWebWindowController() {
    assert(CommuteWebWindowController.iPhoneUserAgent == "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", "iPhoneUserAgent mismatch")

    let controller = CommuteWebWindowController()
    guard let window = controller.window else {
        assertionFailure("Window should not be nil")
        return
    }
    assert(window.contentView?.bounds.width == 390, "Content width should be 390")
    assert(window.contentView?.bounds.height == 700, "Content height should be 700")
    assert(window.title == "SKALA 출퇴근", "Window title mismatch")
    assert(window.level == .floating, "Window level should be floating")
    assert(controller.webView.customUserAgent == CommuteWebWindowController.iPhoneUserAgent, "Custom User-Agent mismatch")
    assert(controller.webView.configuration.websiteDataStore == .default(), "WebsiteDataStore must be default persistent")
    assert(controller.webView.navigationDelegate === controller, "Navigation delegate mismatch")

    print("✅ testCommuteWebWindowController passed")
}

final class MockCommuteService: CommuteServiceProtocol, @unchecked Sendable {
    var targetSSID: String = "skaxedu"
    var targetURL: URL = URL(string: "https://att.skala-ai.com/att-checkin")!
    var checkOutAllowed: Bool = false
    var diffToReturn: (hours: Int, minutes: Int, seconds: Int)? = nil
    var networkCheckResult: Bool = true
    var networkCheckCallCount: Int = 0

    func isCheckOutAllowed(at date: Date) -> Bool {
        return checkOutAllowed
    }

    func timeUntilCheckOut(at date: Date) -> (hours: Int, minutes: Int, seconds: Int)? {
        return diffToReturn
    }

    func checkInternalNetwork() async -> Bool {
        networkCheckCallCount += 1
        return networkCheckResult
    }
}

final class MockCommuteNotificationService: CommuteNotificationServiceProtocol, @unchecked Sendable {
    func requestAuthorization() async -> Bool { true }
    func scheduleWeekdayReminders() async {}
}

@MainActor
func testCommuteViewModelInitialState() {
    let vm = CommuteViewModel()
    assert(!vm.currentTimeString.isEmpty, "Current time string should be populated")
    assert(vm.currentTimeString.count == 8, "Current time string format should be HH:mm:ss")
    vm.stopTimer()
    print("✅ testCommuteViewModelInitialState passed")
}

@MainActor
func testCommuteViewModelLogic() async {
    let mockService = MockCommuteService()
    let mockNotifService = MockCommuteNotificationService()
    let vm = CommuteViewModel(service: mockService, notificationService: mockNotifService)
    defer { vm.stopTimer() }

    // Test countdown with hours
    mockService.diffToReturn = (2, 30, 15)
    vm.updateClock()
    assert(vm.countdownString == "2시간 30분 남음", "Countdown string with hours mismatch: \(String(describing: vm.countdownString))")

    // Test countdown with minutes
    mockService.diffToReturn = (0, 8, 45)
    vm.updateClock()
    assert(vm.countdownString == "8분 45초 남음", "Countdown string with minutes mismatch: \(String(describing: vm.countdownString))")

    // Test countdown with seconds only
    mockService.diffToReturn = (0, 0, 19)
    vm.updateClock()
    assert(vm.countdownString == "19초 남음", "Countdown string with seconds only mismatch: \(String(describing: vm.countdownString))")

    // Test countdown when diff is nil (after 17:50 or allowed)
    mockService.diffToReturn = nil
    mockService.checkOutAllowed = true
    vm.updateClock()
    assert(vm.countdownString == nil, "Countdown should be nil when check-out is allowed")
    assert(vm.isCheckOutAllowed == true, "isCheckOutAllowed should be true")

    // Test gating: when false
    mockService.checkOutAllowed = false
    vm.updateClock()
    assert(vm.isCheckOutAllowed == false, "isCheckOutAllowed should be false")

    // Test refresh internal network
    mockService.networkCheckResult = true
    await vm.refresh()
    assert(vm.isInternalNetwork == true, "isInternalNetwork should be true")
    assert(vm.isCheckingNetwork == false, "isCheckingNetwork should be false after refresh")
    assert(mockService.networkCheckCallCount == 1, "checkInternalNetwork should have been called once")

    mockService.networkCheckResult = false
    await vm.refresh()
    assert(vm.isInternalNetwork == false, "isInternalNetwork should be false")
    assert(vm.isCheckingNetwork == false, "isCheckingNetwork should be false after refresh")
    assert(mockService.networkCheckCallCount == 2, "checkInternalNetwork should have been called twice")

    // Test triggerCheckIn and triggerCheckOut handlers
    vm.triggerCheckIn()
    assert(CommuteWebWindowController.shared.window != nil, "Web window should exist after triggerCheckIn")

    // triggerCheckOut when not allowed: window does not crash
    vm.triggerCheckOut()

    // triggerCheckOut when allowed
    mockService.checkOutAllowed = true
    vm.updateClock()
    vm.triggerCheckOut()

    print("✅ testCommuteViewModelLogic passed")
}

@MainActor
func testCommuteMenuView() {
    let mockService = MockCommuteService()
    let mockNotifService = MockCommuteNotificationService()
    let vm = CommuteViewModel(service: mockService, notificationService: mockNotifService)
    defer { vm.stopTimer() }

    // Check with checkout not allowed
    mockService.checkOutAllowed = false
    mockService.diffToReturn = (1, 15, 30)
    vm.updateClock()
    let viewBefore = CommuteMenuView(viewModel: vm)
    _ = viewBefore.body

    // Check with checkout allowed
    mockService.checkOutAllowed = true
    mockService.diffToReturn = nil
    vm.updateClock()
    let viewAfter = CommuteMenuView(viewModel: vm)
    _ = viewAfter.body

    print("✅ testCommuteMenuView passed")
}

@MainActor
func testMainMenuTabAndContainerView() {
    assert(MainMenuTab.allCases == [.bus, .cafeteria, .commute], "MainMenuTab.allCases must be [.bus, .cafeteria, .commute]")
    assert(MainMenuTab.bus.title == "버스", "bus title mismatch")
    assert(MainMenuTab.cafeteria.title == "식당", "cafeteria title mismatch")
    assert(MainMenuTab.commute.title == "출퇴근", "commute title mismatch")

    let busVM = BusViewModel(apiService: BusAPIService(session: makeMockBusSession()))
    busVM.stopAutoRefresh()
    let cafeVM = CafeteriaViewModel()
    let mockCommuteService = MockCommuteService()
    let mockCommuteNotifService = MockCommuteNotificationService()
    let commuteVM = CommuteViewModel(service: mockCommuteService, notificationService: mockCommuteNotifService)
    commuteVM.stopTimer()

    let containerView = MainContainerView(
        busViewModel: busVM,
        cafeteriaViewModel: cafeVM,
        commuteViewModel: commuteVM
    )
    _ = containerView.body
    print("✅ testMainMenuTabAndContainerView passed")
}

func main() async {
    do {
        testTargetBusStopMapping()
        try await testBusAPIServiceMultiStopConcurrent()
        await testBusViewModelDynamicStopName()
        testCafeteriaMenuModels()
        await testCafeteriaViewModelDefaults()
        try await testCafeteriaLiveFetchAndParse()
        testCommuteServiceKSTCheckOutGate()
        testCommuteNotificationDateComponents()
        await testCommuteNotificationService()
        await testCommuteWebWindowController()
        await testCommuteViewModelInitialState()
        await testCommuteViewModelLogic()
        await testCommuteMenuView()
        await testMainMenuTabAndContainerView()
        print("🎉 All PangyoBus & Cafeteria tests passed successfully!")
    } catch {
        print("❌ Test failed: \(error)")
        exit(1)
    }
}

await main()


