#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="SKALA-MenuBar"
VERSION="1.4.0"
BUNDLE_ID="com.skala.menubar"
DIST_DIR="$PROJECT_ROOT/dist"
ROOT_DIR="$DIST_DIR/root"
APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"
DMG_STAGING="$DIST_DIR/dmg_staging"
DMG_OUTPUT="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
DMG_LATEST="$DIST_DIR/${APP_NAME}.dmg"

echo "🔨 1. Swift 릴리즈 빌드 중..."
swift build -c release

echo "📁 2. macOS 앱 번들 구조 생성 중 ($APP_NAME.app)..."
mkdir -p "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 바이너리 복사
cp "$PROJECT_ROOT/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 앱 아이콘 복사
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
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
    <string>10</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 불필요한 메타 파일 및 격리 속성 제거
export COPYFILE_DISABLE=1
find "$APP_BUNDLE" -name '._*' -delete 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# macOS 시스템 알림 및 권한 등록을 위한 ad-hoc 코드 서명
echo "✍️  앱 번들 코드 서명 중 (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "💿 3. DMG 스테이징 디렉토리 준비 중..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# 앱 번들 복사
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Applications 심볼릭 링크 생성 (드래그 앤 드롭 설치 지원)
ln -s /Applications "$DMG_STAGING/Applications"

# 볼륨 아이콘 설정 (아이콘 파일이 있는 경우)
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$DMG_STAGING/.VolumeIcon.icns"
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -c icnC "$DMG_STAGING/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "$DMG_STAGING" 2>/dev/null || true
    fi
fi

# 스테이징 디렉토리 확장 속성 정리
find "$DMG_STAGING" -name '._*' -delete 2>/dev/null || true
xattr -cr "$DMG_STAGING" 2>/dev/null || true

echo "📦 4. hdiutil로 DMG 디스크 이미지 생성 중..."
rm -f "$DMG_OUTPUT" "$DMG_LATEST"
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_STAGING" \
               -ov \
               -format UDZO \
               "$DMG_OUTPUT"

# DMG 자체의 확장 속성 정리 및 ad-hoc 서명
xattr -cr "$DMG_OUTPUT" 2>/dev/null || true
codesign --force --sign - "$DMG_OUTPUT" 2>/dev/null || true

# 최신 고정 파일명으로도 복사 (SKALA-MenuBar.dmg)
cp "$DMG_OUTPUT" "$DMG_LATEST"

# 임시 스테이징 디렉토리 정리
rm -rf "$DMG_STAGING"

echo ""
echo "🎉 DMG 빌드 완료!"
echo "📍 생성된 DMG: $DMG_OUTPUT"
echo "📍 최신 링크용: $DMG_LATEST"
ls -lh "$DMG_OUTPUT" "$DMG_LATEST"
