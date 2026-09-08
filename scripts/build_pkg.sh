#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="SKALA-MenuBar"
VERSION="1.1.0"
BUNDLE_ID="com.skala.menubar"
DIST_DIR="$PROJECT_ROOT/dist"
ROOT_DIR="$DIST_DIR/root"
APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"
PKG_OUTPUT="$DIST_DIR/${APP_NAME}-${VERSION}.pkg"

echo "🔨 1. Swift 릴리즈 빌드 중..."
swift build -c release

echo "📁 2. macOS 앱 번들 구조 생성 중 ($APP_NAME.app)..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 바이너리 복사
cp "$PROJECT_ROOT/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist 생성 (메뉴바 전용 속성 LSUIElement 포함)
cat << PLIST > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko_KR</string>
    <key>CFBundleDisplayName</key>
    <string>SKALA MenuBar</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 불필요한 메타 파일 제거
export COPYFILE_DISABLE=1
find "$ROOT_DIR" -name '._*' -delete 2>/dev/null || true

echo "📦 3. pkgbuild로 정식 macOS 설치 패키지 생성 중..."
pkgbuild --root "$ROOT_DIR" \
         --identifier "$BUNDLE_ID" \
         --version "$VERSION" \
         --install-location "/Applications" \
         "$PKG_OUTPUT"

echo ""
echo "🎉 빌드 완료!"
echo "📍 생성된 패키지: $PKG_OUTPUT"
ls -lh "$PKG_OUTPUT"
