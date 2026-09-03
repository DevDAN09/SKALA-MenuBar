# 🚌 PangyoBus Menubar (판교 9007 버스 메뉴바)

SK AX 판교캠퍼스 인근(**SK플래닛·판교디지털센터** 정류장)에서 서울역/고속터미널 방면으로 운행하는 **9007번 직행좌석버스**의 실시간 도착 시간을 macOS 메뉴바에 표시해 주는 초경량 네이티브 앱입니다.

---

## ✨ 주요 기능
- **실시간 메뉴바 상태 표시**:
  - `🚌 9007: 12분 (8전)` (일반 도착 예정)
  - `🚨 9007: 2분 전 (1전)` (3분 이내 곧 도착)
  - `🚌 9007: 정보 없음` (차고지 대기 또는 운행 종료)
- **원클릭 상세 팝업**:
  - 첫 번째 버스 및 두 번째 버스의 남은 시간, 남은 정류장 수, 차량 번호 표시
  - 실시간 마지막 갱신 시각
- **주기적 자동 갱신**: 15초 / 30초 / 60초 주기 선택 가능
- **단축키 지원**:
  - `⌘R`: 지금 즉시 새로고침
  - `⌘Q`: 앱 종료
- **무의존성 & 초경량**:
  - 별도의 API 키 발급 불필요
  - 서드파티 라이브러리 의존성 0 (Apple Swift Standard Library & SwiftUI Native)
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
.build/release/PangyoBus &
```

### 백그라운드 프로세스 종료
메뉴바를 클릭한 후 `종료` 버튼을 누르거나 `⌘Q`를 누르거나, 터미널에서 아래 명령을 실행합니다:
```bash
pkill -f PangyoBus
```

---

## 🛠️ 테스트 실행
```bash
swift build
.build/debug/PangyoBusTests
```
