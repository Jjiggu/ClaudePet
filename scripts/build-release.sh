#!/usr/bin/env bash
# scripts/build-release.sh
# Usage: ./scripts/build-release.sh [version]
# Output: dist/ClaudePet-{version}.dmg + SHA256 출력

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${REPO_ROOT}/ClaudePet.xcodeproj"
SCHEME="ClaudePet"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${REPO_ROOT}/build"

if [[ $# -ge 1 ]]; then
    VERSION="$1"
else
    VERSION=$(grep -m1 'MARKETING_VERSION' "${PROJECT}/project.pbxproj" \
              | sed 's/.*= //;s/;//;s/ //')
fi
echo "[build-release] Version: ${VERSION}"

rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}" "${BUILD_DIR}"

ARCHIVE_PATH="${BUILD_DIR}/ClaudePet.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"

cat > "${EXPORT_OPTIONS_PLIST}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

echo "[build-release] Archiving…"
xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    SKIP_INSTALL=NO

APP_PATH="${EXPORT_PATH}/ClaudePet.app"

echo "[build-release] Exporting .app…"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

# 폴백: export 실패 시 archive에서 직접 복사
if [[ ! -d "${APP_PATH}" ]]; then
    APP_PATH="${ARCHIVE_PATH}/Products/Applications/ClaudePet.app"
fi

echo "[build-release] Verifying signature…"
codesign --verify --deep --strict "${APP_PATH}" && echo "  Signature OK"

echo "[build-release] Creating DMG…"
DMG_STAGING="${BUILD_DIR}/dmg-staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/ClaudePet.app"
ln -s /Applications "${DMG_STAGING}/Applications"

DMG_TEMP="${BUILD_DIR}/ClaudePet-tmp.dmg"
DMG_FINAL="${DIST_DIR}/ClaudePet-${VERSION}.dmg"

hdiutil create \
    -volname "ClaudePet ${VERSION}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDRW \
    "${DMG_TEMP}"

hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

rm -f "${DMG_TEMP}"

echo ""
echo "────────────────────────────────────────"
echo "Output: ${DMG_FINAL}"
echo "Size:   $(du -sh "${DMG_FINAL}" | cut -f1)"
echo ""
echo "SHA256 (Casks/claudepet.rb에 붙여넣기):"
shasum -a 256 "${DMG_FINAL}" | awk '{print $1}'
echo "────────────────────────────────────────"
