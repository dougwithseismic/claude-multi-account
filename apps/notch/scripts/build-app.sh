#!/bin/zsh
# Builds "Claude Notch.app" and the claude-usage command into apps/notch/build/ and signs both.
# With --install, also replaces ~/Applications/Claude Notch.app with it and opens it.
#
# Keychain "Always Allow" is tied to the app's signature. An ad hoc signature changes
# with every build, so macOS would ask again after each one; a certificate's doesn't.
# Signs with $CODESIGN_IDENTITY, else the first code-signing identity in the login
# Keychain, else ad hoc (with a warning).
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release --product ClaudeNotch
swift build -c release --product claude-usage

APP="build/Claude Notch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeNotch "$APP/Contents/MacOS/ClaudeNotch"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.godzillaaa.claude-notch</string>
  <key>CFBundleName</key><string>Claude Notch</string>
  <key>CFBundleExecutable</key><string>ClaudeNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.4</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>Claude links</string>
      <key>CFBundleURLSchemes</key><array><string>claude</string></array>
    </dict>
  </array>
  <key>NSAppleEventsUsageDescription</key>
  <string>Claude Notch passes claude:// links, such as sign-in, to the copy of Claude you used last.</string>
</dict>
</plist>
PLIST

IDENTITY=${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/\)/ { print $2; exit }')}
if [[ -z $IDENTITY ]]; then
  echo "No code-signing certificate found; signing ad hoc. macOS will ask for Keychain access after every build." >&2
  IDENTITY=-
fi
codesign --force --sign "$IDENTITY" --identifier com.godzillaaa.claude-notch "$APP"
codesign --verify --strict "$APP"
cp .build/release/claude-usage build/claude-usage
codesign --force --sign "$IDENTITY" --identifier com.godzillaaa.claude-usage build/claude-usage
echo "Built $PWD/$APP and $PWD/build/claude-usage"

if [[ ${1:-} == --install ]]; then
  DEST="$HOME/Applications/Claude Notch.app"
  LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  pkill -x ClaudeNotch && sleep 1 || true
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  # Only the installed copy should receive claude:// links.
  "$LSREGISTER" -u "$PWD/$APP" 2>/dev/null || true
  "$LSREGISTER" -f "$DEST"
  open "$DEST"
  echo "Installed and opened $DEST"
fi
