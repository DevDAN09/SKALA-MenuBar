# 출퇴근 트리거 & 알림 기능 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 메뉴바 앱(SKALA-MenuBar)에 사내 출퇴근 사이트(`https://att.skala-ai.com/att-checkin`)를 전용 모바일 웹뷰로 호출하는 출퇴근 트리거 탭, 17:50 KST 퇴실 제어, 사내 Wi-Fi(`skaxedu`) 감지 및 평일 08:50/17:50 시스템 리마인더 알림을 구현한다.

**Architecture:** `CommuteService`(KST 시간 계산, Wi-Fi 및 연결성 감지)와 `CommuteNotificationService`(평일 08:50/17:50 알림)를 기반으로 `CommuteViewModel`이 상태를 관리한다. UI는 3번째 탭인 `CommuteMenuView`로 노출되며, 버튼 클릭 시 iPhone Safari User-Agent를 탑재한 독립 플로팅 윈도우 `CommuteWebWindowController`를 띄워 사람이 직접 Google SSO 로그인 및 입퇴실 버튼을 누를 수 있도록 지원한다.

**Tech Stack:** Swift 5.9, AppKit, SwiftUI, WebKit (`WKWebView`), UserNotifications (`UNUserNotificationCenter`), SystemConfiguration / CoreWLAN.

**Spec:** `docs/superpowers/specs/2026-09-09-commute-trigger-design.md`

## Global Constraints

- 퇴실(퇴근) 버튼은 한국 표준시(KST, `Asia/Seoul`) 기준 17:50 이후에만 활성화되어야 함.
- 사내 Wi-Fi(`skaxedu`) 연결 여부를 감지하여 비연결 시 경고를 표시해야 함.
- 대상 사이트는 모바일 전용이므로 `WKWebView`의 `customUserAgent`를 iPhone Safari UA로 설정해야 함.
- Google SSO 세션 유지를 위해 `WKWebsiteDataStore.default()`를 사용해야 함.
- **웹뷰 내 자동 클릭(JS DOM 조작 등) 및 자동화 E2E 클릭 테스트는 절대 수행하지 않으며, 버튼 클릭은 사람이 직접 수행함.**
- 외부 의존성(외부 라이브러리) 추가 없이 Swift 표준 라이브러리 및 Apple 내장 프레임워크만 사용함.

---

### Task 1: KST 시간 판별 및 Wi-Fi 감지 서비스 (`CommuteService`)

**Files:**
- Create: `Sources/SKALAMenuBarKit/Services/CommuteService.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift` (추가 테스트 함수 등록)

**Interfaces:**
- Produces:
  ```swift
  public protocol CommuteServiceProtocol {
      var targetSSID: String { get }
      var targetURL: URL { get }
      func isCheckOutAllowed(at date: Date) -> Bool
      func timeUntilCheckOut(at date: Date) -> (hours: Int, minutes: Int, seconds: Int)?
      func checkInternalNetwork() async -> Bool
  }
  public final class CommuteService: CommuteServiceProtocol {
      public static let shared = CommuteService()
      public let targetSSID: String = "skaxedu"
      public let targetURL: URL = URL(string: "https://att.skala-ai.com/att-checkin")!
      public init() {}
      public func isCheckOutAllowed(at date: Date = Date()) -> Bool
      public func timeUntilCheckOut(at date: Date = Date()) -> (hours: Int, minutes: Int, seconds: Int)?
      public func checkInternalNetwork() async -> Bool
  }
  ```

- [ ] **Step 1: Write the failing test**

In `Tests/SKALAMenuBarTests/main.swift`:
```swift
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

    print("✅ testCommuteServiceKSTCheckOutGate passed")
}
```
And add `testCommuteServiceKSTCheckOutGate()` to `main()` in `Tests/SKALAMenuBarTests/main.swift`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift run SKALAMenuBarTests`
Expected: Compile error `cannot find 'CommuteService' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Sources/SKALAMenuBarKit/Services/CommuteService.swift`:
```swift
import Foundation

public protocol CommuteServiceProtocol: Sendable {
    var targetSSID: String { get }
    var targetURL: URL { get }
    func isCheckOutAllowed(at date: Date) -> Bool
    func timeUntilCheckOut(at date: Date) -> (hours: Int, minutes: Int, seconds: Int)?
    func checkInternalNetwork() async -> Bool
}

public final class CommuteService: CommuteServiceProtocol, @unchecked Sendable {
    public static let shared = CommuteService()

    public let targetSSID: String = "skaxedu"
    public let targetURL: URL = URL(string: "https://att.skala-ai.com/att-checkin")!

    private let kstTimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    public init() {}

    public func isCheckOutAllowed(at date: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kstTimeZone

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        return (hour > 17) || (hour == 17 && minute >= 50)
    }

    public func timeUntilCheckOut(at date: Date = Date()) -> (hours: Int, minutes: Int, seconds: Int)? {
        if isCheckOutAllowed(at: date) {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kstTimeZone

        var targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        targetComponents.hour = 17
        targetComponents.minute = 50
        targetComponents.second = 0

        guard let targetDate = calendar.date(from: targetComponents) else {
            return nil
        }

        let diff = Int(targetDate.timeIntervalSince(date))
        if diff <= 0 { return nil }

        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        return (hours, minutes, seconds)
    }

    public func checkInternalNetwork() async -> Bool {
        // 1. Check current Wi-Fi SSID via networksetup or CLI if available
        let ssid = getCurrentWiFiSSID()
        if let ssid = ssid, ssid == targetSSID {
            return true
        }

        // 2. Reachability fallback: HEAD request to targetURL with short timeout
        var request = URLRequest(url: targetURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                return true
            }
        } catch {
            // Unreachable outside internal network
        }

        return false
    }

    private func getCurrentWiFiSSID() -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", "en0"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Format: "Current Wi-Fi Network: skaxedu"
                let prefix = "Current Wi-Fi Network: "
                if let range = output.range(of: prefix) {
                    let ssid = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    return ssid.isEmpty ? nil : ssid
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift run SKALAMenuBarTests`
Expected: Output includes `✅ testCommuteServiceKSTCheckOutGate passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/SKALAMenuBarKit/Services/CommuteService.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: add CommuteService with KST 17:50 gating and Wi-Fi check"
```

---

### Task 2: 평일 08:50 및 17:50 시스템 알림 서비스 (`CommuteNotificationService`)

**Files:**
- Create: `Sources/SKALAMenuBarKit/Services/CommuteNotificationService.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift`

**Interfaces:**
- Produces:
  ```swift
  public protocol CommuteNotificationServiceProtocol: Sendable {
      func requestAuthorization() async -> Bool
      func scheduleWeekdayReminders() async
  }
  public final class CommuteNotificationService: CommuteNotificationServiceProtocol {
      public static let shared = CommuteNotificationService()
      public static let morningNotificationId = "skala.commute.morning.checkin"
      public static let eveningNotificationId = "skala.commute.evening.checkout"
      public init() {}
      public func requestAuthorization() async -> Bool
      public func scheduleWeekdayReminders() async
  }
  ```

- [ ] **Step 1: Write the failing test**

In `Tests/SKALAMenuBarTests/main.swift`:
```swift
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
```
And call it in `main()`.

- [ ] **Step 2: Run test to verify it passes**

Run: `swift run SKALAMenuBarTests`
Expected: Passes

- [ ] **Step 3: Write implementation of CommuteNotificationService**

Create `Sources/SKALAMenuBarKit/Services/CommuteNotificationService.swift`:
```swift
import Foundation
import UserNotifications

public protocol CommuteNotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleWeekdayReminders() async
}

public final class CommuteNotificationService: CommuteNotificationServiceProtocol, @unchecked Sendable {
    public static let shared = CommuteNotificationService()

    public static let morningNotificationId = "skala.commute.morning.checkin"
    public static let eveningNotificationId = "skala.commute.evening.checkout"

    private let center = UNUserNotificationCenter.current()
    private let kstTimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    public init() {}

    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func scheduleWeekdayReminders() async {
        // Remove existing to avoid duplication
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.morningNotificationId,
            Self.eveningNotificationId
        ])

        var kstCalendar = Calendar(identifier: .gregorian)
        kstCalendar.timeZone = kstTimeZone

        // Weekdays: Monday(2) ~ Friday(6)
        let weekdays = [2, 3, 4, 5, 6]

        for weekday in weekdays {
            // 1. Morning 08:50 KST
            let morningContent = UNMutableNotificationContent()
            morningContent.title = "⏰ [SKALA] 출석 확인 알림"
            morningContent.body = "8시 50분입니다. 오늘 입실(출석) 체크하셨나요?"
            morningContent.sound = .default

            var morningComps = DateComponents()
            morningComps.timeZone = kstTimeZone
            morningComps.weekday = weekday
            morningComps.hour = 8
            morningComps.minute = 50

            let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningComps, repeats: true)
            let morningReq = UNNotificationRequest(
                identifier: "\(Self.morningNotificationId).\(weekday)",
                content: morningContent,
                trigger: morningTrigger
            )
            try? await center.add(morningReq)

            // 2. Evening 17:50 KST
            let eveningContent = UNMutableNotificationContent()
            eveningContent.title = "👋 [SKALA] 퇴근 체크인 알림"
            eveningContent.body = "17시 50분입니다. 지금 퇴실(퇴근) 체크가 가능합니다!"
            eveningContent.sound = .default

            var eveningComps = DateComponents()
            eveningComps.timeZone = kstTimeZone
            eveningComps.weekday = weekday
            eveningComps.hour = 17
            eveningComps.minute = 50

            let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningComps, repeats: true)
            let eveningReq = UNNotificationRequest(
                identifier: "\(Self.eveningNotificationId).\(weekday)",
                content: eveningContent,
                trigger: eveningTrigger
            )
            try? await center.add(eveningReq)
        }
    }
}
```

- [ ] **Step 4: Run test to verify build and test runner**

Run: `swift run SKALAMenuBarTests`
Expected: Passes

- [ ] **Step 5: Commit**

```bash
git add Sources/SKALAMenuBarKit/Services/CommuteNotificationService.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: add CommuteNotificationService for weekday 08:50 and 17:50 reminders"
```

---

### Task 3: 모바일 웹뷰 독립 윈도우 컨트롤러 (`CommuteWebWindowController`)

**Files:**
- Create: `Sources/SKALAMenuBarKit/Views/CommuteWebWindowController.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor
  public final class CommuteWebWindowController: NSWindowController {
      public static let shared = CommuteWebWindowController()
      public func show(url: URL = CommuteService.shared.targetURL)
  }
  ```

- [ ] **Step 1: Write implementation of CommuteWebWindowController**

Create `Sources/SKALAMenuBarKit/Views/CommuteWebWindowController.swift`:
```swift
import AppKit
import WebKit

@MainActor
public final class CommuteWebWindowController: NSWindowController, WKNavigationDelegate {
    public static let shared = CommuteWebWindowController()

    private var webView: WKWebView!
    private var progressIndicator: NSProgressIndicator!

    public static let iPhoneUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SKALA 출퇴근"
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = self.window else { return }

        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]

        // Top toolbar bar
        let toolbarView = NSView(frame: NSRect(x: 0, y: containerView.bounds.height - 38, width: containerView.bounds.width, height: 38))
        toolbarView.autoresizingMask = [.width, .minYMargin]

        let reloadBtn = NSButton(title: "새로고침", target: self, action: #selector(didTapReload))
        reloadBtn.bezelStyle = .rounded
        reloadBtn.frame = NSRect(x: 8, y: 6, width: 75, height: 26)
        toolbarView.addSubview(reloadBtn)

        let titleLabel = NSTextField(labelWithString: "att.skala-ai.com")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 90, y: 8, width: containerView.bounds.width - 180, height: 20)
        titleLabel.autoresizingMask = [.width]
        toolbarView.addSubview(titleLabel)

        progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: containerView.bounds.width, height: 2))
        progressIndicator.isIndeterminate = false
        progressIndicator.style = .bar
        progressIndicator.autoresizingMask = [.width]
        progressIndicator.isHidden = true
        toolbarView.addSubview(progressIndicator)

        containerView.addSubview(toolbarView)

        // WKWebView Configuration
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Persistent Google SSO session

        let webFrame = NSRect(x: 0, y: 0, width: containerView.bounds.width, height: containerView.bounds.height - 38)
        webView = WKWebView(frame: webFrame, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.customUserAgent = Self.iPhoneUserAgent
        webView.navigationDelegate = self

        containerView.addSubview(webView)
        window.contentView = containerView
    }

    public func show(url: URL = CommuteService.shared.targetURL) {
        guard let window = self.window else { return }

        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func didTapReload() {
        webView.reload()
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `swift build`
Expected: Build complete!

- [ ] **Step 3: Commit**

```bash
git add Sources/SKALAMenuBarKit/Views/CommuteWebWindowController.swift
git commit -m "feat: add CommuteWebWindowController with iPhone Safari UA and persistent session"
```

---

### Task 4: 출퇴근 ViewModel (`CommuteViewModel`)

**Files:**
- Create: `Sources/SKALAMenuBarKit/ViewModels/CommuteViewModel.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift`

**Interfaces:**
- Consumes: `CommuteServiceProtocol`, `CommuteNotificationServiceProtocol`, `CommuteWebWindowController`
- Produces:
  ```swift
  @MainActor
  public final class CommuteViewModel: ObservableObject {
      @Published public var isInternalNetwork: Bool
      @Published public var isCheckOutAllowed: Bool
      @Published public var currentTimeString: String
      @Published public var countdownString: String?
      @Published public var isCheckingNetwork: Bool

      public init(service: CommuteServiceProtocol, notificationService: CommuteNotificationServiceProtocol)
      public func refresh() async
      public func triggerCheckIn()
      public func triggerCheckOut()
  }
  ```

- [ ] **Step 1: Write minimal implementation**

Create `Sources/SKALAMenuBarKit/ViewModels/CommuteViewModel.swift`:
```swift
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

    public init(
        service: CommuteServiceProtocol = CommuteService.shared,
        notificationService: CommuteNotificationServiceProtocol = CommuteNotificationService.shared
    ) {
        self.service = service
        self.notificationService = notificationService
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

    public func updateClock() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = kstTimeZone
        formatter.dateFormat = "HH:mm:ss"
        currentTimeString = formatter.string(from: now)

        isCheckOutAllowed = service.isCheckOutAllowed(at: now)

        if let diff = service.timeUntilCheckOut(at: now) {
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
}
```

- [ ] **Step 2: Add test in `Tests/SKALAMenuBarTests/main.swift`**

```swift
@MainActor
func testCommuteViewModelInitialState() {
    let vm = CommuteViewModel()
    assert(!vm.currentTimeString.isEmpty, "Current time string should be populated")
    print("✅ testCommuteViewModelInitialState passed")
}
```
And add call in `main()`.

- [ ] **Step 3: Run test to verify it passes**

Run: `swift run SKALAMenuBarTests`
Expected: Output includes `✅ testCommuteViewModelInitialState passed`

- [ ] **Step 4: Commit**

```bash
git add Sources/SKALAMenuBarKit/ViewModels/CommuteViewModel.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: add CommuteViewModel with real-time clock and trigger handlers"
```

---

### Task 5: 출퇴근 탭 화면 (`CommuteMenuView`)

**Files:**
- Create: `Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift`

**Interfaces:**
- Consumes: `CommuteViewModel`
- Produces:
  ```swift
  public struct CommuteMenuView: View {
      @ObservedObject var viewModel: CommuteViewModel
      public init(viewModel: CommuteViewModel)
  }
  ```

- [ ] **Step 1: Write implementation of CommuteMenuView**

Create `Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift`:
```swift
import SwiftUI

public struct CommuteMenuView: View {
    @ObservedObject var viewModel: CommuteViewModel

    public init(viewModel: CommuteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Network Status Card
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isInternalNetwork ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                if viewModel.isCheckingNetwork {
                    Text("네트워크 확인 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if viewModel.isInternalNetwork {
                    Text("skaxedu 사내망 연결됨")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text("사내 Wi-Fi(skaxedu) 연결 권장")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)

            // 2. KST Clock & Check-out Status Card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("한국 표준시 (KST)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentTimeString)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Text("퇴실(퇴근) 가능 기준")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.isCheckOutAllowed {
                        Text("지금 퇴실 가능 🟢")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else if let countdown = viewModel.countdownString {
                        Text("17:50 (\(countdown))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)

            // 3. Action Buttons
            HStack(spacing: 8) {
                // Check-in Button
                Button {
                    viewModel.triggerCheckIn()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                        Text("입실하기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Check-out Button
                Button {
                    viewModel.triggerCheckOut()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk.departure")
                        Text("퇴실하기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.isCheckOutAllowed ? Color.accentColor : Color.secondary.opacity(0.18))
                    .foregroundColor(viewModel.isCheckOutAllowed ? .white : .secondary.opacity(0.6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isCheckOutAllowed)
            }

            // 4. Notification Footer Info
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("평일 08:50 출석 / 17:50 퇴근 알림")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 320)
        .task {
            await viewModel.refresh()
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `swift build`
Expected: Build complete!

- [ ] **Step 3: Commit**

```bash
git add Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift
git commit -m "feat: add CommuteMenuView with real-time status and trigger buttons"
```

---

### Task 6: 메인 컨테이너 및 앱 엔트리포인트 연동

**Files:**
- Modify: `Sources/SKALAMenuBarKit/Views/MainContainerView.swift`
- Modify: `Sources/SKALAMenuBar/main.swift`

**Interfaces:**
- Updates: `MainMenuTab` to include `.commute`
- Updates: `MainContainerView` to accept `CommuteViewModel`
- Updates: `SKALAMenuBarApp` to initialize `CommuteViewModel` and schedule weekday reminders on launch.

- [ ] **Step 1: Update MainContainerView.swift**

In `Sources/SKALAMenuBarKit/Views/MainContainerView.swift`:
Add `.commute` to `MainMenuTab`:
```swift
public enum MainMenuTab: CaseIterable {
    case bus, cafeteria, commute

    var title: String {
        switch self {
        case .bus: return "버스"
        case .cafeteria: return "식당"
        case .commute: return "출퇴근"
        }
    }
}
```
Update tab icons and switcher:
```swift
// Icon logic:
if tab == .bus {
    Image(systemName: "bus.fill")
        .font(.system(size: 13))
} else if tab == .cafeteria {
    Text("🍱")
        .font(.system(size: 13))
} else {
    Image(systemName: "clock.badge.checkmark")
        .font(.system(size: 13))
}

// Switcher:
switch selectedTab {
case .bus:
    BusStatusMenuView(viewModel: busViewModel)
case .cafeteria:
    CafeteriaMenuView(viewModel: cafeteriaViewModel)
        .frame(width: 320)
case .commute:
    CommuteMenuView(viewModel: commuteViewModel)
        .frame(width: 320)
}
```
Update initializer and `.task` to refresh `commuteViewModel`.

- [ ] **Step 2: Update main.swift**

In `Sources/SKALAMenuBar/main.swift`:
```swift
@StateObject private var commuteViewModel = CommuteViewModel()
```
Pass `commuteViewModel` to `MainContainerView`.
In `init()` or `.task`:
```swift
Task {
    await CommuteNotificationService.shared.requestAuthorization()
    await CommuteNotificationService.shared.scheduleWeekdayReminders()
}
```

- [ ] **Step 3: Run test and build verification**

Run: `swift build`
Run: `swift run SKALAMenuBarTests`
Expected: Build passes, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/SKALAMenuBarKit/Views/MainContainerView.swift Sources/SKALAMenuBar/main.swift
git commit -m "feat: integrate Commute tab and notification scheduling into main app"
```

---

### Task 7: 빌드 및 무인 단위 테스트 검증 & 수동 E2E 안내

**Files:**
- Test: All unit test suites in `Tests/SKALAMenuBarTests/main.swift`

**Requirements:**
- **절대 웹페이지 DOM 자동 클릭 테스트를 실행하지 않는다.**
- 단위 테스트와 빌드 무결성만 검증한다.

- [ ] **Step 1: Execute full test suite**

Run: `swift run SKALAMenuBarTests`
Expected: 
`🎉 All tests passed successfully!`

- [ ] **Step 2: Build release binary**

Run: `swift build -c release`
Expected: Successful compile of `SKALA-MenuBar`.

- [ ] **Step 3: Commit and summarize for human partner manual verification**

Provide clear human-in-the-loop manual testing guide for the user to perform E2E verification (clicking 입실 / 퇴실 in the popup window).
