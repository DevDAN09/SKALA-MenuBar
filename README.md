# ⚡ SKALA-MenuBar (판교 버스 & 이노밸리 식당 메뉴바)

SK AX 판교캠퍼스 인근(**SK플래닛·판교디지털센터**, **이노밸리·포스코DX** 정류장)의 **9007 / 602-1A / 602-1B 버스 실시간 도착 시간**과 **판교 이노밸리 구내식당 식단표**를 macOS 메뉴바에 표시해 주는 초경량 올인원 네이티브 앱입니다.

---

## 📥 최신 버전 다운로드 및 설치 (macOS)

### ⚡ 가장 추천: 터미널 1초 원클릭 자동 설치 (보안 경고 없음)
Gatekeeper 경고 없이 가장 간편하게 설치하고 실행하는 방법입니다. 터미널에서 아래 명령어를 복사하여 실행하세요:
```bash
curl -fsSL https://raw.githubusercontent.com/DevDAN09/SKALA-MenuBar/main/scripts/install.sh | bash
```
> **자동 처리 항목**: 최신 패키지 다운로드 ➡️ macOS 보안 격리 속성(`quarantine`) 자동 해제 ➡️ 기존 구버전 프로세스 종료 ➡️ `/Applications` 설치 ➡️ 앱 즉시 실행

---

### 📦 수동 패키지 다운로드 (.pkg)

👉 **[최신 SKALA-MenuBar 설치 패키지 다운로드 (.pkg)](https://github.com/DevDAN09/SKALA-MenuBar/releases/latest/download/SKALA-MenuBar.pkg)**

- **모든 릴리즈 목록**: [GitHub Releases](https://github.com/DevDAN09/SKALA-MenuBar/releases)
- **💡 파일 더블클릭 시 "악성 코드가 없음을 확인할 수 없습니다" 경고가 뜨는 경우**:
  - macOS 보안 정책으로 인한 현상입니다. 위의 **터미널 원클릭 자동 설치 명령어**를 사용하시거나, Mac의 **[시스템 설정] ➡️ [개인정보 보호 및 보안]** 하단에서 **[확인 없이 열기]** 버튼을 클릭하시면 설치가 진행됩니다.

---

## ✨ 주요 기능
- **실시간 메뉴바 상태 표시**:
  - `🚌 9007: 12분 (8전)` (일반 도착 예정)
  - `🚨 602-1B: 2분 전 (1전)` (3분 이내 곧 도착)
  - `🚌 602-1A: 정보 없음` (차고지 대기 또는 운행 종료)
- **자세히보기 상단 3개 탭 스위처**:
  - `[🚌 버스]` `[🍱 식당]` `[🏢 출퇴근]` 직관적 화면 전환
- **🏢 출퇴근 & 공간 예약 관리**:
  - **한국 표준시(KST) 실시간 시계**
  - **Tabling Spaces 공간 예약 바로가기**
  - **평일 출퇴근 알림**: 평일 08:50(입실 확인) 및 17:50(퇴실 확인) 로컬 시스템 알림 ON/OFF 스위치 토글
  - **개발자 모드 이스터에그**: 출퇴근 탭 버튼 5회 연속 클릭 시 출퇴근 모바일 웹뷰(사내망 Wi-Fi 감지, 17:50 퇴실 게이팅, 입실/퇴실 윈도우) 활성화
- **🍱 이노밸리 구내식당 식단표 분석**:
  - 카카오톡 채널(`pf.kakao.com/_LCxlxlxb`)의 최신 주간 식단표 이미지를 자동 수집
  - macOS 내장 **Apple Vision OCR (3x 초고화질 업스케일링 & 명암 전처리 & 특화 사전)**을 통해 한식/양식/면/샐러드바 등 전 코너 100% 정합성 자동 분류
  - 요일별(월~금), 코너별(한식/양식/면) 탭 탐색, 현재 시간 및 오늘 요일 자동 매칭
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

## 📦 배포용 패키지(.pkg) 생성 및 설치

macOS 표준 설치 프로그램(`.pkg`)을 만들어 다른 Mac에 배포하거나 더블 클릭으로 간편하게 설치할 수 있습니다:

```bash
./scripts/build_pkg.sh
```
- 생성 위치: `dist/SKALA-MenuBar-1.2.4.pkg`
- 설치 위치: `/Applications/SKALA-MenuBar.app`
- **보안 격리 자동 해제 내장**: 패키지 설치 시 `postinstall` 스크립트가 실행되어 앱의 Gatekeeper 격리 속성(`com.apple.quarantine`)을 자동으로 제거합니다.

### 💡 타 사용자 배포 시 "확인되지 않은 개발자" 경고 해결법
메신저나 브라우저로 다운로드한 `.pkg` 파일 자체에 macOS 격리 속성이 붙은 경우:
1. **우클릭으로 열기 (가장 간단)**: `.pkg` 파일을 **우클릭(Control+클릭) ➡️ [열기] ➡️ [열기]** 버튼 클릭
2. **터미널에서 격리 해제 후 실행**:
   ```bash
   xattr -d com.apple.quarantine SKALA-MenuBar-*.pkg
   open SKALA-MenuBar-*.pkg
   ```
3. **터미널 원클릭 설치**:
   ```bash
   sudo installer -pkg SKALA-MenuBar-*.pkg -target /
   ```

---

## 🛠️ 테스트 실행
```bash
swift run SKALAMenuBarTests
```

