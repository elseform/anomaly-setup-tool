#!/usr/bin/env bash
# Compile the wrapper UI and authored Icon Composer asset; never install an app.
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:?Usage: build-launcher.sh <resource-output-directory> <version>}"
# The launcher always carries the version of the setup tool that builds it.
VERSION="${2:?Usage: build-launcher.sh <resource-output-directory> <version>}"
GENERATED_DIR="$(mktemp -d)"
trap 'rm -rf "$GENERATED_DIR"' EXIT
printf 'enum BuildInfo {\n    static let version = "%s"\n}\n' "$VERSION" > "$GENERATED_DIR/BuildInfo.swift"
if ! xcrun --find actool >/dev/null 2>&1; then
  echo 'Full Xcode with Icon Composer support is required to build wrapper icons. Select it with xcode-select.' >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
swiftc -parse-as-library -O -target arm64-apple-macosx26.0 \
  -framework SwiftUI -framework AppKit \
  "$ROOT_DIR"/sources/AnomalyLauncher/*.swift "$GENERATED_DIR/BuildInfo.swift" -o "$OUTPUT_DIR/AnomalyLauncher"
# New wrappers use the setup tool's icon.
if ! xcrun actool "$ROOT_DIR/sources/AnomalySetupTool/SetupTool.icon" \
  --compile "$OUTPUT_DIR" --platform macosx --minimum-deployment-target 26.0 \
  --app-icon SetupTool --output-partial-info-plist "$OUTPUT_DIR/icon-info.plist" \
  --output-format human-readable-text; then
  echo 'Could not compile SetupTool.icon. Full Xcode with Icon Composer support is required.' >&2
  exit 1
fi
# The launch grid tiles: each Resources/<name>.icon becomes <name>.icns beside
# the launcher; only that flat icon is kept, not a second Assets.car.
for tile in mo2 anomalyexes custom; do
  TILE_DIR="$GENERATED_DIR/$tile"
  mkdir -p "$TILE_DIR"
  if ! xcrun actool "$ROOT_DIR/sources/AnomalyLauncher/Resources/$tile.icon" \
    --compile "$TILE_DIR" --platform macosx --minimum-deployment-target 26.0 \
    --app-icon "$tile" --output-partial-info-plist "$TILE_DIR/info.plist" \
    --output-format human-readable-text >/dev/null || [[ ! -s "$TILE_DIR/$tile.icns" ]]; then
    echo "Could not compile $tile.icon. Full Xcode with Icon Composer support is required." >&2
    exit 1
  fi
  cp "$TILE_DIR/$tile.icns" "$OUTPUT_DIR/$tile.icns"
done
codesign --force --sign - --timestamp=none "$OUTPUT_DIR/AnomalyLauncher"
