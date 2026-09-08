#!/bin/bash
set -e

echo "⚡ SKALA-MenuBar 자동 설치를 시작합니다..."

TMP_PKG="/tmp/SKALA-MenuBar.pkg"
LATEST_URL="https://github.com/DevDAN09/SKALA-MenuBar/releases/latest/download/SKALA-MenuBar.pkg"

echo "📥 최신 릴리즈 패키지 다운로드 중..."
curl -fsSL "$LATEST_URL" -o "$TMP_PKG"

echo "🔓 macOS 보안 격리(Gatekeeper quarantine) 해제 중..."
xattr -cr "$TMP_PKG" 2>/dev/null || true

echo "🛑 실행 중인 기존 SKALA-MenuBar 프로세스 정리..."
killall SKALA-MenuBar 2>/dev/null || true

echo "📦 패키지 설치 진행 중 (/Applications)..."
sudo installer -pkg "$TMP_PKG" -target /

echo "🛡️ 설치된 애플리케이션 보안 속성 최종 정리..."
xattr -cr "/Applications/SKALA-MenuBar.app" 2>/dev/null || true
rm -f "$TMP_PKG"

echo ""
echo "🎉 SKALA-MenuBar 설치가 성공적으로 완료되었습니다!"
echo "🚀 앱을 실행합니다..."
open -a "/Applications/SKALA-MenuBar.app"
