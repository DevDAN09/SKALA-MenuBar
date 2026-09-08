# ⚡ SKALA-MenuBar (판교 버스 & 이노밸리 식당 메뉴바)

SK AX 판교캠퍼스 인근(**SK플래닛·판교디지털센터**, **이노밸리·포스코DX** 정류장)의 **9007 / 602-1A / 602-1B 버스 실시간 도착 시간**과 **판교 이노밸리 구내식당 식단표**를 macOS 메뉴바에 표시해 주는 초경량 올인원 네이티브 앱입니다.

---

## ✨ 주요 기능
- **실시간 메뉴바 상태 표시**:
  - `🚌 9007: 12분 (8전)` (일반 도착 예정)
  - `🚨 602-1B: 2분 전 (1전)` (3분 이내 곧 도착)
  - `🚌 602-1A: 정보 없음` (차고지 대기 또는 운행 종료)
- **자세히보기 상단 2개 탭 스위처**:
  - `[🚌 버스]` `[🍱 식당]` 원클릭 직관적 화면 전환
- **🍱 이노밸리 구내식당 식단표 분석**:
  - 카카오톡 채널(`pf.kakao.com/_LCxlxlxb`)의 최신 주간 식단표 이미지를 자동 수집
  - macOS 내장 **Apple Vision OCR (2x 고화질 보간)**을 통해 한식/양식/면/샐러드바 등 전 코너 100% 정합성 자동 분류
  - 요일별(월~금) 및 식사별(조식/중식/석식) 탭 탐색, 현재 시간 및 오늘 요일 자동 매칭
  - 주간 식단 로컬 캐시로 초고속(0초) 로딩 및 원본 이미지 링크 제공
- **단축키 지원**:
  - `⌘R`: 지금 즉시 새로고침
  - `⌘Q`: 앱 종료
- **무의존성 & 초경량**:
  - 외부 유료 API 키나 브라우저 자동화 도구 불필요
  - 서드파티 라이브러리 의존성 0 (Apple Swift Standard Library, SwiftUI, Vision Native)
  - Dock에 아이콘 없이 메뉴바에만 상주 (`NSApplication.ActivationPolicy.accessory`)

---

## 🚀 실행 방법

### 간편 실행 스크립트
```bash
./scripts/run.sh
```

### 직접 빌드 및 실행
```bash
swift build -c release
.build/release/SKALA-MenuBar &
```

### 백그라운드 프로세스 종료
메뉴바를 클릭한 후 `종료` 버튼을 누르거나 `⌘Q`를 누르거나, 터미널에서 아래 명령을 실행합니다:
```bash
pkill -f SKALA-MenuBar
```

---

## 📦 배포용 패키지(.pkg) 생성

macOS 표준 설치 프로그램(`.pkg`)을 만들어 다른 Mac에 배포하거나 더블 클릭으로 간편하게 설치할 수 있습니다:

```bash
./scripts/build_pkg.sh
```
- 생성 위치: `dist/SKALA-MenuBar-1.1.0.pkg` (~220KB)
- 설치 위치: `/Applications/SKALA-MenuBar.app` (더블 클릭 시 macOS 표준 설치 마법사 진행)
- 메뉴바 전용(`LSUIElement: true`)으로 백그라운드에 가볍게 실행됩니다.

---

## 🛠️ 테스트 실행
```bash
swift run SKALA-MenuBarTests
```

