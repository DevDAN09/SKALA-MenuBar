# SKCT 화이트보드, 계산기 및 '생활' 탭 구현 계획 (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 '출퇴근' 탭 영역을 '생활' 탭으로 개편하고, 마우스로 작성 가능한 화이트보드(펜, 지우개, 전체 지우기, 되돌리기)와 우측 상단 CBT 계산기(접기/펼치기 및 키보드 지원)를 갖춘 독립 전용 윈도우 기반의 SKCT 모의 환경을 제공합니다.

**Architecture:** 순수 Swift/SwiftUI와 AppKit `NSWindowController`를 활용하여 서드파티 의존성 없는 네이티브 독립 창(`SKCTWindowController`)을 띄웁니다. 캔버스는 SwiftUI `Canvas`와 벡터 스트로크 기반으로 고성능 렌더링되며, 계산기는 우측 상단에 반투명 글래스 패널(`SKCTCalculatorView`)로 오버레이되어 접기/펼치기가 가능합니다. 메뉴바의 '생활' 탭 카드 버튼을 통해 즉시 실행됩니다.

**Tech Stack:** macOS 13.0+, Swift 5.9+, SwiftUI, AppKit, XCTest / Custom Test Suite

**Spec:** `docs/superpowers/specs/2026-09-17-skct-whiteboard-calculator-design.md`

## Global Constraints
- 플랫폼 및 타겟: macOS 13.0+ (`Package.swift` 플랫폼 사양 준수)
- 의존성: 외부 서드파티 라이브러리 추가 없이 Apple Native 프레임워크(SwiftUI, AppKit)만 사용
- 탭 명칭: `MainMenuTab.commute`의 `title`은 `"생활"`로 변경
- 전체 지우기: 캔버스 전체 지우기(`clearAll()`) 지원 및 `undo()`로 복구 가능하도록 상태 저장
- 기존 기능 보존: KST 시계, Tabling 예약, 평일 알림, 개발자 모드(사내망 체크인) 100% 정상 동작

---

### Task 1: CBT 계산기 연산 엔진 (`SKCTCalculatorEngine.swift`) 및 단위 테스트

**Files:**
- Create: `Sources/SKALAMenuBarKit/Models/SKCTCalculatorEngine.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct SKCTCalculatorEngine {
      public private(set) var displayText: String
      public private(set) var expressionText: String
      public mutating func inputDigit(_ digit: String)
      public mutating func inputDecimal()
      public mutating func inputOperation(_ op: Operation)
      public mutating func calculateEquals()
      public mutating func clear()
      public mutating func backspace()
      public mutating func toggleSign()
      public mutating func applyPercent()
  }
  ```

- [ ] **Step 1: 실패하는 단위 테스트 작성**
`Tests/SKALAMenuBarTests/main.swift`에 `testSKCTCalculatorEngine()` 테스트 함수를 추가하고 메인 실행 목록에 등록합니다.
```swift
func testSKCTCalculatorEngine() {
    var engine = SKCTCalculatorEngine()
    assert(engine.displayText == "0", "Initial display should be 0")

    // 12 + 34 = 46
    engine.inputDigit("1")
    engine.inputDigit("2")
    assert(engine.displayText == "12")
    engine.inputOperation(.add)
    engine.inputDigit("3")
    engine.inputDigit("4")
    assert(engine.displayText == "34")
    engine.calculateEquals()
    assert(engine.displayText == "46", "12 + 34 should be 46")

    // Backspace test
    engine.clear()
    engine.inputDigit("1")
    engine.inputDigit("2")
    engine.inputDigit("5")
    engine.backspace()
    assert(engine.displayText == "12")

    // Divide by zero
    engine.clear()
    engine.inputDigit("8")
    engine.inputOperation(.divide)
    engine.inputDigit("0")
    engine.calculateEquals()
    assert(engine.displayText == "오류", "Divide by zero should show 오류")

    print("✅ testSKCTCalculatorEngine passed")
}
```

- [ ] **Step 2: 테스트 실행 및 실패 확인**
Run: `swift run SKALAMenuBarTests`
Expected: 컴파일 에러 (`Cannot find 'SKCTCalculatorEngine' in scope`)

- [ ] **Step 3: 계산기 엔진 구현 (`SKCTCalculatorEngine.swift`)**
`Sources/SKALAMenuBarKit/Models/SKCTCalculatorEngine.swift` 파일을 생성하고 사칙연산, 소수점, 백분율, 백스페이스, 클리어 로직을 구현합니다.

- [ ] **Step 4: 테스트 재실행 및 통과 확인**
Run: `swift run SKALAMenuBarTests`
Expected: `testSKCTCalculatorEngine passed`

- [ ] **Step 5: 커밋**
```bash
git add Sources/SKALAMenuBarKit/Models/SKCTCalculatorEngine.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: add SKCTCalculatorEngine and unit tests"
```

---

### Task 2: 화이트보드 드로잉 모델 및 뷰모델 (`SKCTDrawingViewModel.swift`)과 단위 테스트

**Files:**
- Create: `Sources/SKALAMenuBarKit/ViewModels/SKCTDrawingViewModel.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum WhiteboardTool: Equatable { case pen, eraser }
  public struct DrawingStroke: Identifiable, Equatable { ... }
  public final class SKCTDrawingViewModel: ObservableObject {
      @Published public var strokes: [DrawingStroke]
      @Published public var currentStroke: DrawingStroke?
      @Published public var activeTool: WhiteboardTool
      @Published public var selectedColor: Color
      @Published public var selectedLineWidth: CGFloat
      public func startStroke(at point: CGPoint)
      public func continueStroke(to point: CGPoint)
      public func finishStroke()
      public func eraseStrokes(near point: CGPoint)
      public func clearAll()
      public func undo()
      public func redo()
  }
  ```

- [ ] **Step 1: 실패하는 단위 테스트 작성**
`Tests/SKALAMenuBarTests/main.swift`에 `testSKCTDrawingViewModel()` 함수를 작성합니다.
```swift
@MainActor
func testSKCTDrawingViewModel() {
    let vm = SKCTDrawingViewModel()
    assert(vm.activeTool == .pen)
    assert(vm.strokes.isEmpty)

    // Draw stroke
    vm.startStroke(at: CGPoint(x: 10, y: 10))
    vm.continueStroke(to: CGPoint(x: 20, y: 20))
    vm.finishStroke()
    assert(vm.strokes.count == 1, "Should have 1 stroke")

    // Undo
    vm.undo()
    assert(vm.strokes.isEmpty, "Should be empty after undo")
    vm.redo()
    assert(vm.strokes.count == 1, "Should restore after redo")

    // Clear All
    vm.clearAll()
    assert(vm.strokes.isEmpty, "Should be empty after clearAll")
    vm.undo()
    assert(vm.strokes.count == 1, "Undo should restore cleared canvas")

    // Eraser
    vm.activeTool = .eraser
    vm.eraseStrokes(near: CGPoint(x: 15, y: 15))
    assert(vm.strokes.isEmpty, "Intersecting stroke should be erased")

    print("✅ testSKCTDrawingViewModel passed")
}
```

- [ ] **Step 2: 테스트 실행 및 실패 확인**
Run: `swift run SKALAMenuBarTests`
Expected: 컴파일 에러 (`Cannot find 'SKCTDrawingViewModel' in scope`)

- [ ] **Step 3: `SKCTDrawingViewModel.swift` 구현**
`Sources/SKALAMenuBarKit/ViewModels/SKCTDrawingViewModel.swift`를 작성하여 펜 획 생성, 드래그 점 추가, 거리 기반 지우개(`eraseStrokes`), `clearAll()` (전체 지우기), `undo()`, `redo()` 로직을 구현합니다.

- [ ] **Step 4: 테스트 재실행 및 통과 확인**
Run: `swift run SKALAMenuBarTests`
Expected: `testSKCTDrawingViewModel passed`

- [ ] **Step 5: 커밋**
```bash
git add Sources/SKALAMenuBarKit/ViewModels/SKCTDrawingViewModel.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: add SKCTDrawingViewModel with pen, eraser, and clearAll"
```

---

### Task 3: 화이트보드 캔버스 및 CBT 계산기 SwiftUI 뷰 구현

**Files:**
- Create: `Sources/SKALAMenuBarKit/Views/SKCTCalculatorView.swift`
- Create: `Sources/SKALAMenuBarKit/Views/SKCTWhiteboardView.swift`
- Create: `Sources/SKALAMenuBarKit/Views/SKCTPracticeView.swift`

**Interfaces:**
- Consumes: `SKCTCalculatorEngine`, `SKCTDrawingViewModel`
- Produces: `SKCTPracticeView: View` (전체 모의 환경 메인 뷰)

- [ ] **Step 1: `SKCTCalculatorView.swift` 구현**
우측 상단 플로팅 패널. 접기/펼치기 토글 헤더, LCD 디스플레이, 버튼 키패드 그리드(C, ⌫, %, ÷, 7, 8, 9, ×, 4, 5, 6, -, 1, 2, 3, +, 0, 00, ., =), 키보드 이벤트 지원.

- [ ] **Step 2: `SKCTWhiteboardView.swift` 구현**
SwiftUI `Canvas` 기반 렌더링. 상단 툴바에 `[펜]`, `[지우개]` 전환 토글, 선 굵기/색상 선택기, `[되돌리기]`, `[다시실행]`, **`[전체 지우기]`** 버튼 배치. 마우스 드래그 제스처로 실시간 드로잉/지우기.

- [ ] **Step 3: `SKCTPracticeView.swift` 구현**
`ZStack(alignment: .topTrailing)`으로 배경에 `SKCTWhiteboardView`, 우측 상단에 `SKCTCalculatorView`를 오버레이 배치.

- [ ] **Step 4: 빌드 검증**
Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 5: 커밋**
```bash
git add Sources/SKALAMenuBarKit/Views/SKCTCalculatorView.swift Sources/SKALAMenuBarKit/Views/SKCTWhiteboardView.swift Sources/SKALAMenuBarKit/Views/SKCTPracticeView.swift
git commit -m "feat: create SKCT whiteboard canvas, calculator, and practice views"
```

---

### Task 4: AppKit 윈도우 컨트롤러 (`SKCTWindowController.swift`) 구현

**Files:**
- Create: `Sources/SKALAMenuBarKit/Views/SKCTWindowController.swift`
- Test: `Tests/SKALAMenuBarTests/main.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor
  public final class SKCTWindowController: NSWindowController {
      public static let shared = SKCTWindowController()
      public func show()
  }
  ```

- [ ] **Step 1: 실패하는 단위 테스트 작성**
`Tests/SKALAMenuBarTests/main.swift`에 `testSKCTWindowController()`를 추가합니다.
```swift
@MainActor
func testSKCTWindowController() {
    let controller = SKCTWindowController.shared
    controller.show()
    guard let window = controller.window else {
        assertionFailure("SKCT Window should not be nil")
        return
    }
    assert(window.title == "SKCT 모의 환경 (화이트보드 & 계산기)", "Window title mismatch")
    assert(window.frame.width >= 800, "Window width should be at least 800")
    assert(window.frame.height >= 550, "Window height should be at least 550")
    print("✅ testSKCTWindowController passed")
}
```

- [ ] **Step 2: 테스트 실행 및 실패 확인**
Run: `swift run SKALAMenuBarTests`
Expected: 컴파일 에러 (`Cannot find 'SKCTWindowController' in scope`)

- [ ] **Step 3: `SKCTWindowController.swift` 구현**
1000x700 크기, 타이틀바, 리사이즈 가능, NSHostingController(rootView: SKCTPracticeView())를 윈도우 contentView로 등록.

- [ ] **Step 4: 테스트 재실행 및 통과 확인**
Run: `swift run SKALAMenuBarTests`
Expected: `testSKCTWindowController passed`

- [ ] **Step 5: 커밋**
```bash
git add Sources/SKALAMenuBarKit/Views/SKCTWindowController.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: implement SKCTWindowController for standalone whiteboard & calculator"
```

---

### Task 5: '출퇴근' 탭을 '생활' 탭으로 개편 및 SKCT 연습장 바로가기 연동

**Files:**
- Modify: `Sources/SKALAMenuBarKit/Views/MainContainerView.swift:3-13, 50-75`
- Modify: `Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift:16-59`
- Modify: `Tests/SKALAMenuBarTests/main.swift:551-560`

- [ ] **Step 1: 테스트 코드 수정 (기존 "출퇴근" 기대값 ➡️ "생활")**
`Tests/SKALAMenuBarTests/main.swift`의 `testMainMenuTabAndContainerView`에서:
`assert(MainMenuTab.commute.title == "생활", "commute title mismatch")` 로 갱신.

- [ ] **Step 2: 테스트 실행 및 실패 확인**
Run: `swift run SKALAMenuBarTests`
Expected: assertion failure ("commute title mismatch: 출퇴근 != 생활")

- [ ] **Step 3: `MainContainerView.swift` 및 `CommuteMenuView.swift` 수정**
1. `MainMenuTab.commute.title`: `"생활"`로 변경.
2. 탭 아이콘: `Image(systemName: "sparkles")` 또는 `Image(systemName: "house.fill")`로 교체.
3. `CommuteMenuView.swift`: 상단 KST 시계 카드 아래에 **[📝 SKCT 온라인 연습장 열기]** 카드 버튼 추가 (클릭 시 `SKCTWindowController.shared.show()` 호출).

- [ ] **Step 4: 테스트 재실행 및 통과 확인**
Run: `swift run SKALAMenuBarTests`
Expected: 모든 테스트 성공 통과

- [ ] **Step 5: 커밋**
```bash
git add Sources/SKALAMenuBarKit/Views/MainContainerView.swift Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift Tests/SKALAMenuBarTests/main.swift
git commit -m "feat: rename commute tab to life tab and add SKCT launcher card"
```

---

### Task 6: 최종 빌드, 릴리즈 패키징 및 문서 업데이트

**Files:**
- Modify: `README.md`
- Test: Full build & test suite

- [ ] **Step 1: README.md 주요 기능 업데이트**
출퇴근 ➡️ 생활 탭 변경점 및 SKCT 화이트보드/계산기 기능 설명 추가.

- [ ] **Step 2: 전체 단위 테스트 및 릴리즈 빌드 실행**
Run: `swift run SKALAMenuBarTests`
Run: `swift build -c release`
Expected: 성공

- [ ] **Step 3: 최종 커밋**
```bash
git add README.md
git commit -m "docs: update README with SKCT whiteboard and life tab features"
```
