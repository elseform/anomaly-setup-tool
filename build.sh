#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_VERSION="0.96"
BUILD_DIR="$ROOT_DIR/dist"
INTERMEDIATES_DIR="$BUILD_DIR/intermediates"
APP_DIR="$BUILD_DIR/Anomaly Setup Tool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_RESOURCES_DIR="$ROOT_DIR/sources/AnomalySetupTool/Resources"
BINARY="$MACOS_DIR/Anomaly Setup Tool"
INTERMEDIATE_BINARY="$INTERMEDIATES_DIR/Anomaly Setup Tool"
ENGINE_BINARY="$RESOURCES_DIR/anomaly-setup-engine"
INTERMEDIATE_ENGINE_BINARY="$INTERMEDIATES_DIR/anomaly-setup-engine"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
MODE="${1:-build}"

# build:  build dist/, sign it, and install it into ~/Applications
# bundle: build and sign dist/ only (what test.sh uses; installs nothing)
# install: copy the dist/ app that `bundle` (or test.sh) just built into
#          ~/Applications without rebuilding; refuses a bundle older than the sources
# run:    build dist/ and run the app binary directly
case "$MODE" in
  build|bundle|install|run|clean)
    ;;
  *)
    printf 'Usage: %s [build|bundle|install|run|clean]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

if [[ "$MODE" == "clean" ]]; then
  rm -rf "$BUILD_DIR"
  printf 'Removed %s\n' "$BUILD_DIR"
  exit 0
fi

INSTALL_DIR="$HOME/Applications"

if [[ "$MODE" == "install" ]]; then
  if [[ ! -x "$BINARY" ]]; then
    printf 'No built app at %s; run ./test.sh or ./build.sh bundle first.\n' "$APP_DIR" >&2
    exit 1
  fi
  newer_source="$(find "$ROOT_DIR/sources" "$ROOT_DIR/build.sh" -type f -newer "$BINARY" -print -quit)"
  if [[ -n "$newer_source" ]]; then
    printf 'The built app is older than %s; run ./test.sh or ./build.sh bundle first.\n' "$newer_source" >&2
    exit 1
  fi
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/Anomaly Setup Tool.app"
  cp -R "$APP_DIR" "$INSTALL_DIR/Anomaly Setup Tool.app"
  printf '%s\n' "$INSTALL_DIR/Anomaly Setup Tool.app"
  exit 0
fi

is_stale() {
  local output="$1"
  shift

  if [[ ! -e "$output" ]]; then
    return 0
  fi

  local input
  for input in "$@"; do
    if [[ "$input" -nt "$output" ]]; then
      return 0
    fi
  done

  return 1
}

# Assemble the bundle from scratch so files removed from the sources do not
# linger in dist/ (and from there in the installed app). Compiled binaries are
# kept in $INTERMEDIATES_DIR, outside the bundle.
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR" "$INTERMEDIATES_DIR"

swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macosx26.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework SwiftUI \
  -framework AppKit \
  "$ROOT_DIR"/sources/AnomalySetupCore/*.swift \
  "$ROOT_DIR"/sources/AnomalySetupTool/*.swift \
  -o "$INTERMEDIATE_BINARY"

cp "$INTERMEDIATE_BINARY" "$BINARY"

bash "$ROOT_DIR/scripts/build-launcher.sh" "$RESOURCES_DIR/launcher" "$APP_VERSION"

if [[ "$MODE" != "run" ]] || is_stale "$INTERMEDIATE_ENGINE_BINARY" "$ROOT_DIR"/sources/AnomalySetupCore/*.swift "$ROOT_DIR"/sources/AnomalySetupEngine/main.swift; then
  swiftc \
    -O \
    -target arm64-apple-macosx26.0 \
    -module-cache-path "$MODULE_CACHE_DIR" \
    "$ROOT_DIR"/sources/AnomalySetupCore/*.swift \
    "$ROOT_DIR"/sources/AnomalySetupEngine/main.swift \
    -o "$INTERMEDIATE_ENGINE_BINARY"
fi

cp "$INTERMEDIATE_ENGINE_BINARY" "$ENGINE_BINARY"
chmod +x "$ENGINE_BINARY"

# The app icon is an Icon Composer document; actool compiles it into
# Assets.car plus a SetupTool.icns fallback (full Xcode required, as for the
# launcher icon above).
if ! xcrun actool "$ROOT_DIR/sources/AnomalySetupTool/SetupTool.icon" \
  --compile "$RESOURCES_DIR" --platform macosx --minimum-deployment-target 26.0 \
  --app-icon SetupTool --output-partial-info-plist "$INTERMEDIATES_DIR/setup-tool-icon-info.plist" \
  --output-format human-readable-text >/dev/null; then
  echo 'Could not compile SetupTool.icon. Full Xcode with Icon Composer support is required.' >&2
  exit 1
fi
if [[ -d "$SOURCE_RESOURCES_DIR/usvfs" ]]; then
  rm -rf "$RESOURCES_DIR/usvfs"
  cp -R "$SOURCE_RESOURCES_DIR/usvfs" "$RESOURCES_DIR/usvfs"
fi
# interactive_setup.py lives here now (sources/AnomalySetupTool/Resources/
# wine-engine/), not in anomaly-wine-engine — no cross-repo sync needed.
rm -rf "$RESOURCES_DIR/wine-engine"
cp -R "$SOURCE_RESOURCES_DIR/wine-engine" "$RESOURCES_DIR/wine-engine"
rm -rf "$RESOURCES_DIR/wine-engine/__pycache__"
chmod +x "$RESOURCES_DIR/wine-engine/interactive_setup.py"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Anomaly Setup Tool</string>
  <key>CFBundleIconFile</key>
  <string>SetupTool</string>
  <key>CFBundleIconName</key>
  <string>SetupTool</string>
  <key>CFBundleIdentifier</key>
  <string>com.elseform.anomaly-setup-tool</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Anomaly Setup Tool</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>APP_VERSION_PLACEHOLDER</string>
  <key>CFBundleVersion</key>
  <string>APP_VERSION_PLACEHOLDER</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

perl -0pi -e "s/APP_VERSION_PLACEHOLDER/$APP_VERSION/g" "$CONTENTS_DIR/Info.plist"

if [[ "$MODE" == "build" || "$MODE" == "bundle" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
fi

if [[ "$MODE" == "build" ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/Anomaly Setup Tool.app"
  cp -R "$APP_DIR" "$INSTALL_DIR/Anomaly Setup Tool.app"
  printf '%s\n' "$INSTALL_DIR/Anomaly Setup Tool.app"
fi

if [[ "$MODE" == "run" ]]; then
  "$BINARY"
fi
