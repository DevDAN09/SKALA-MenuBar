# SKALA-MenuBar 출퇴근 트리거 & 알림 기능 설계 명세서 (Design Spec)

- **작성일자**: 2026-09-09
- **대상 프로젝트**: `SKALA-MenuBar` (macOS 네이티브 메뉴바 앱)
- **주요 목적**: 사내 출퇴근(입실/퇴실) 체크인 시스템(`https://att.skala-ai.com/att-checkin`)을 메뉴바에서 손쉽게 열 수 있는 트리거 버튼 및 평일 오전 출석 알림 기능 추가.

---

## 1. 요구사항 및 배경

1. **출퇴근 트리거 버튼**:
   - 메뉴바 앱 내에 `[입실하기]`(출근) 및 `[퇴실하기]`(퇴근) 버튼 제공.
   - **퇴실 제약 조건**: 한국 표준시(KST) 기준 **17:50 이후에만 퇴실 버튼이 활성화**되어야 함 (17:50 이전에는 비활성화 및 안내 문구 노출).
2. **네트워크 및 모바일 환경 제약**:
   - 대상 사이트는 사내 Wi-Fi(`skaxedu`)에 연결되어 있어야만 접근 가능.
   - 대상 사이트는 데스크톱 접근 시 "모바일 환경에서만 접속 가능" 에러가 발생하므로 **Mobile User-Agent**(iPhone Safari)로 접근해야 함.
   - Google SSO 로그인이 필요함 (Google 2FA / 계정 인증).
   - **수동 클릭 원칙**: 웹뷰 내에서 사람이 직접 로그인 및 입실/퇴실 버튼을 클릭하도록 하며, **자동 클릭 스크립트(JS Injection 등)는 일체 배제**.
3. **평일 정기 리마인더 알림**:
   - **오전 출석 알림**: 매주 평일(월~금) **오전 08:50 KST**에 입실(출석) 여부를 확인하는 macOS 시스템 로컬 알림 발송.
   - **오후 퇴근 알림**: 매주 평일(월~금) **오후 17:50 KST**에 퇴실(퇴근) 체크가 활성화되었음을 알리는 macOS 시스템 로컬 알림 발송.

---

## 2. 시스템 아키텍처 및 화면 구성

```
[메뉴바 상단 탭 스위처]
  ├── [🚌 버스]
  ├── [🍱 식당]
  └── [⏰ 출퇴근] (신규)

[출퇴근 탭 뷰 (CommuteMenuView)]
  ├── 1. 네트워크 상태 배지
  │      - 🟢 skaxedu 연결됨 (정상)
  │      - 🔴 skaxedu 미연결 (사내 Wi-Fi 연결 필요 안내)
  ├── 2. 시간 현황 및 가이드 카드
  │      - 현재 한국 시간(KST) 실시간 시계 표시
  │      - 17:50 이전: "퇴실 가능까지 X시간 Y분 남음 (17:50 이후 활성화)"
  │      - 17:50 이후: "지금 퇴실(퇴근) 체크가 가능합니다."
  ├── 3. 액션 버튼 영역
  │      - [🏢 입실하기] : Wi-Fi 연결 시 상시 활성화
  │      - [👋 퇴실하기] : Wi-Fi 연결 + 17:50 KST 이후에만 활성화
  └── 4. 알림 상태 표시
         - "🔔 평일 08:50 출석 / 17:50 퇴근 리마인더 활성화됨"

[버튼 클릭 시: 모바일 웹뷰 윈도우 (CommuteWebWindowController)]
  ├── 창 크기: 390 × 700 pt (iPhone 해상도 비율)
  ├── 윈도우 레벨: .floating (메뉴바가 닫혀도 독립 유지)
  ├── 상단 바: 타이틀("SKALA 출퇴근"), 새로고침 버튼, 닫기 버튼
  └── WKWebView:
        ├── Custom User-Agent: iPhone Safari UA (모바일 제한 우회)
        ├── WebsiteDataStore: .default() (Google SSO 세션/쿠키 유지)
        └── 대상 URL: https://att.skala-ai.com/att-checkin
```

---

## 3. 핵심 비즈니스 로직

### 3.1. KST 17:50 퇴실 기준 계산 (`CommuteService`)
- 타임존: `TimeZone(identifier: "Asia/Seoul")` 고정.
- `isCheckOutAllowed(at date: Date = Date()) -> Bool`:
  - `Calendar(identifier: .gregorian)` 기반으로 KST 기준의 `hour`와 `minute` 추출.
  - `(hour > 17) || (hour == 17 && minute >= 50)` 일 때 `true` 반환.
- `timeUntilCheckOut(at date: Date = Date()) -> (hours: Int, minutes: Int, seconds: Int)?`:
  - 17:50 이전일 경우 남은 시간/분/초 계산하여 UI 카운트다운 제공.

### 3.2. 사내 Wi-Fi(`skaxedu`) 감지 로직
- 대상 SSID: `"skaxedu"`
- 감지 방식:
  1. `CoreWLAN` 프레임워크의 `CWWiFiClient.shared().interface()?.ssid()` 확인.
  2. 시스템 CLI 도구 (`/usr/sbin/networksetup -getairportnetwork <interface>`)를 통한 보조 확인.
  3. 사내 도메인(`att.skala-ai.com`) 초경량 연결성(HEAD/GET) 체크 병행.
- 결과에 따라 `isInternalNetworkConnected` 상태를 갱신.

### 3.3. 모바일 웹뷰 환경 (`CommuteWebWindowController`)
- `WKWebViewConfiguration`:
  - `websiteDataStore = .default()`: 영구 쿠키 저장소를 사용하여 Google SSO 로그인 상태가 유지되도록 처리.
- `customUserAgent`:
  - `"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"`
- 창 동작:
  - 입실 또는 퇴실 버튼을 누르면 창이 화면 중앙(또는 메뉴바 근처)에 열리며 해당 URL로 이동.
  - 창을 닫아도 다음번 클릭 시 다시 깔끔하게 재오픈.
  - **웹뷰 내 자동 클릭이나 DOM 조작 코드는 절대 삽입하지 않음 (사람이 직접 터치/클릭)**.

### 3.4. 평일 정기 시스템 알림 (`CommuteNotificationService`)
- `UNUserNotificationCenter` 사용:
  - 앱 시작 시 또는 최초 출퇴근 탭 진입 시 알림 권한(`requestAuthorization(options: [.alert, .sound])`) 요청.
  - 평일(월, 화, 수, 목, 금) 2가지 반복 트리거 등록:
    1. **오전 08:50 KST 출석 알림**:
       - 트리거: 평일 매일 오전 8시 50분 (KST)
       - 제목: `⏰ [SKALA] 출석 확인 알림`
       - 본문: `8시 50분입니다. 오늘 입실(출석) 체크하셨나요?`
    2. **오후 17:50 KST 퇴근 알림**:
       - 트리거: 평일 매일 오후 5시 50분 (KST)
       - 제목: `👋 [SKALA] 퇴근 체크인 알림`
       - 본문: `17시 50분입니다. 지금 퇴실(퇴근) 체크가 가능합니다!`
  - 알림 탭(클릭) 시:
    - 앱 활성화 및 `CommuteWebWindowController`를 자동 오픈하여 즉시 체크인 페이지 표시.

---

## 4. 파일 변경 및 추가 계획

| 파일 경로 | 작업 내용 |
| :--- | :--- |
| `Sources/SKALAMenuBarKit/Services/CommuteService.swift` | KST 17:50 판별, 남은 시간 계산, Wi-Fi 감지 서비스 |
| `Sources/SKALAMenuBarKit/Services/CommuteNotificationService.swift` | 평일 08:50 로컬 알림 스케줄링 및 권한 관리 |
| `Sources/SKALAMenuBarKit/ViewModels/CommuteViewModel.swift` | 출퇴근 화면 상태 관리 (실시간 타이머, 버튼 활성화, 창 오픈 트리거) |
| `Sources/SKALAMenuBarKit/Views/CommuteMenuView.swift` | 출퇴근 탭 SwiftUI 뷰 (상태 카드, 실시간 타이머, 입/퇴실 버튼) |
| `Sources/SKALAMenuBarKit/Views/CommuteWebWindow.swift` | 독립 모바일 WKWebView 팝업 윈도우 컨트롤러 |
| `Sources/SKALAMenuBarKit/Views/MainContainerView.swift` | `MainMenuTab`에 `.commute` 추가 및 3개 탭 전환 UI 연동 |
| `Sources/SKALAMenuBar/main.swift` | `CommuteViewModel` 및 알림 서비스 초기화 연결 |
| `Tests/SKALAMenuBarTests/CommuteTests.swift` | 17:50 전후 시간 판별, KST 타임존 정합성, 알림 컴포넌트 단위 테스트 |

---

## 5. 검증 및 테스트 계획

1. **로직 단위 테스트 (Unit Tests)**:
   - `testBefore1750CheckOutDisabled`: 08:00, 17:49 등에서 퇴실 비활성화 검증.
   - `testAfter1750CheckOutEnabled`: 17:50, 18:00, 23:59 등에서 퇴실 활성화 검증.
   - `testKSTTimezoneIntegrity`: 로컬 타임존(UTC, PST 등) 변경 환경에서도 한국 시각 기준 17:50으로 정확히 계산되는지 검증.
   - `testWiFiMatching`: SSID가 `"skaxedu"`일 때와 아닐 때의 감지 분기 검증.
2. **빌드 및 패키지 검증**:
   - `swift build` 및 `swift run SKALAMenuBarTests` 통과.
3. **UI/앱 실행 검증**:
   - 메뉴바에서 `[⏰ 출퇴근]` 탭이 정상 노출되는지 확인.
   - 버튼 클릭 시 모바일 크기(390×700) 팝업 창이 정상적으로 뜨는지 확인.
   - **웹페이지 내부의 실제 로그인 및 입/퇴실 버튼 클릭 E2E 테스트는 사용자가 직접 수행** (자동 클릭 테스트 절대 미수행).
