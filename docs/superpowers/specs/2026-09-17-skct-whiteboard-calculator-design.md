# SKCT 모의 환경(화이트보드 & 계산기) 및 '생활' 탭 개편 설계서

## 1. 개요 및 목적
- 본 문서는 SKALA-MenuBar 앱의 기존 '출퇴근' 탭 영역을 '생활' 탭으로 개편하고, SK 인적성 검사(SKCT) 온라인 CBT 환경을 완벽히 모의할 수 있는 독립 화이트보드(펜, 지우개, 전체 지우기, Undo/Redo) 및 우측 상단 CBT 계산기 기능을 설계합니다.
- 온라인 SKCT 응시 시 주어지는 마우스 필기 메모장 환경과 우측 상단 계산기 조작 환경을 실전과 동일하게 연습할 수 있도록 네이티브 macOS 환경으로 구축합니다.

---

## 2. 윈도우 및 화면 구성 (Architecture & Window)

### 2.1 `SKCTWindowController` (AppKit)
- **클래스명**: `SKCTWindowController: NSWindowController`
- **싱글톤**: `SKCTWindowController.shared`
- **크기**: 기본 1000 × 700 px (최소 크기 800 × 550 px, 사용자가 자유롭게 리사이즈 가능)
- **스타일**: `[.titled, .closable, .miniaturizable, .resizable]`
- **창 제목**: `"SKCT 모의 환경 (화이트보드 & 계산기)"`
- **동작**:
  - `show()` 호출 시 윈도우가 화면 중앙에 생성되거나 기존 창이 전면으로 활성화 (`makeKeyAndOrderFront`).
  - 메뉴바 팝업이 닫혀도 독립적으로 화면에 유지되어 모의고사 웹사이트나 PDF 문제와 함께 병행 연습 가능.

### 2.2 레이아웃 계층 구조 (SwiftUI `SKCTPracticeView`)
- 전체 화면은 `ZStack`으로 구성:
  1. **배경 화이트보드 드로잉 영역 (`SKCTWhiteboardView`)**:
     - 상단 헤더 툴바와 함께 전체 캔버스를 차지.
  2. **우측 상단 계산기 오버레이 (`SKCTCalculatorView`)**:
     - `alignment: .topTrailing`, 우측/상단 여백 16px.
     - 반투명 블러 카드 (`.ultraThinMaterial`, 테두리 1px, 둥근 모서리 12px, 은은한 그림자).
     - 상단 바에 '접기/펼치기' 토글 버튼 제공.

---

## 3. 화이트보드 드로잉 & 전체 지우기 엔진

### 3.1 데이터 모델
```swift
public struct DrawingPoint: Equatable {
    public var x: CGFloat
    public var y: CGFloat
}

public struct DrawingStroke: Identifiable, Equatable {
    public let id: UUID
    public var points: [CGPoint]
    public var color: Color
    public var lineWidth: CGFloat

    public init(id: UUID = UUID(), points: [CGPoint] = [], color: Color = .primary, lineWidth: CGFloat = 2.5) {
        self.id = id
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
}

public enum WhiteboardTool: Equatable {
    case pen
    case eraser
}
```

### 3.2 뷰모델 (`SKCTDrawingViewModel`)
- **상태 관리**:
  - `strokes: [DrawingStroke]`: 현재 캔버스에 그려진 모든 획 리스트
  - `currentStroke: DrawingStroke?`: 현재 마우스 드래그 중인 획
  - `activeTool: WhiteboardTool`: `.pen` 또는 `.eraser`
  - `selectedColor: Color`: 검정(`primary`), 파랑(`blue`), 빨강(`red`)
  - `selectedLineWidth: CGFloat`: 얇게(1.5), 보통(2.5), 두껍게(4.5)
  - `eraserRadius: CGFloat`: 지우개 반경 (15.0)
  - `undoStack: [[DrawingStroke]]`
  - `redoStack: [[DrawingStroke]]`
- **동작 메서드**:
  - `startStroke(at: CGPoint)`: 펜 모드일 때 새 스트로크 생성, 지우개 모드일 때 해당 좌표 근처 획 삭제
  - `continueStroke(to: CGPoint)`: 펜 모드일 때 점 추가, 지우개 모드일 때 접촉 획 지속 삭제
  - `finishStroke()`: 스트로크 완료 후 `strokes`에 추가 및 `undoStack`에 상태 기록 (`redoStack` 초기화)
  - `eraseStrokes(near: CGPoint)`: 드래그 점과의 최소 거리가 `eraserRadius` 이하인 획을 찾아 제거
  - `clearAll()`: **메모장 전체 지우기**. 이전 상태를 `undoStack`에 보존하고 `strokes`를 빈 배열로 초기화
  - `undo()`: 이전 드로잉 상태로 복원
  - `redo()`: 복원 취소

### 3.3 상단 툴바 UI
- **좌측**: `[🖊️ 펜]`, `[🧹 지우개]` 모드 전환 토글
- **중앙**: 펜 색상 피커 (3색 원형 버튼), 선 굵기 슬라이더/버튼
- **우측**: `[↺ 되돌리기]`, `[↻ 다시실행]`, `[🗑️ 전체 지우기]` (원클릭 초기화)

---

## 4. 우측 상단 CBT 계산기 (Top-Right Calculator)

### 4.1 연산 엔진 (`SKCTCalculatorEngine`)
- 부동소수점 오차 방지를 위해 `Decimal` 기반 연산 처리.
- 지원 연산: 사칙연산(`+`, `-`, `×`, `÷`), 백분율(`%`), 소수점(`.`), 부호 반전(`±`), 백스페이스(`⌫`), 전체 초기화(`C/AC`), 결과 산출(`=`).
- 0으로 나누기(`Divide by Zero`) 시 `"오류"` 안내 및 안전한 리셋.
- 천 단위 구분 콤마 서식(`NumberFormatter`) 지원.

### 4.2 계산기 UI 및 접기 기능 (`SKCTCalculatorView`)
- **접힘 상태(`isFolded: Bool`)**:
  - 접혔을 때: 콤팩트한 `[🧮 계산기 펼치기 ▾]` 버튼만 우측 상단에 노출.
  - 펼쳤을 때: 전체 키패드 및 수식/결과 디스플레이 창 표시.
- **키보드 단축키 지원**:
  - 키보드 숫자 `0`~`9`, `+`, `-`, `*`, `/`, `Enter`(`=`), `Backspace`, `Escape`(`C`) 즉시 입력 지원.

---

## 5. 메뉴바 '생활' 탭 연동

### 5.1 탭 명칭 및 아이콘
- `MainMenuTab.commute`의 `title`을 `"출퇴근"`에서 **`"생활"`**로 변경.
- 탭 아이콘을 생활에 어울리는 SF Symbol (`leaf.fill` 또는 `house.fill`)로 교체.
- 탭 열람 시 기존의 개발자 모드 클릭 이스터에그 및 통계 카운트 연동 유지.

### 5.2 '생활' 탭 내 진입 카드 (`CommuteMenuView`)
- 상단 KST 시계 카드 바로 아래에 다음 카드 추가:
  - **[📝 SKCT 온라인 연습장 열기]**
  - 보조 텍스트: "화이트보드 & CBT 계산기 모의 환경"
  - 클릭 시 `SKCTWindowController.shared.show()` 실행.
- 기존 사내 공간 예약(Tabling Spaces), 평일 출퇴근 알림(08:50/17:50), 사내망 웹뷰 출퇴근 기능은 완벽히 유지.

---

## 6. 테스트 및 검증 계획
1. `SKCTCalculatorEngineTests`:
   - 덧셈, 뺄셈, 곱셈, 나눗셈 정합성.
   - 소수점 연산 및 연속 연산(예: `2 + 3 × 4` 또는 순차 계산) 검증.
   - 0으로 나누기 오류 처리 검증.
2. `SKCTDrawingViewModelTests`:
   - 펜 획 추가, 지우개 획 삭제 로직 검증.
   - **전체 지우기(`clearAll()`)** 기능 동작 및 `undo()`로 복구 가능 여부 검증.
3. `MainMenuTabTests`:
   - `MainMenuTab.commute.title == "생활"` 검증.
   - `MainContainerView` 및 `CommuteMenuView` 렌더링 검증.
4. 전체 빌드 및 CLI 테스트 실행 (`swift run SKALAMenuBarTests`) 통과 확인.
