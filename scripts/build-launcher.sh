#!/usr/bin/env bash
# Compile the wrapper UI and authored Icon Composer asset; never install an app.
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:?Usage: build-launcher.sh <resource-output-directory>}"
if ! xcrun --find actool >/dev/null 2>&1; then
  echo 'Full Xcode with Icon Composer support is required to build wrapper icons. Select it with xcode-select.' >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
swiftc -parse-as-library -O -target arm64-apple-macosx15.0 \
  -framework SwiftUI -framework AppKit \
  "$ROOT_DIR"/sources/GAMMALauncher/*.swift -o "$OUTPUT_DIR/GAMMALauncher"
if ! xcrun actool "$ROOT_DIR/sources/GAMMALauncher/Resources/Gamma.icon" \
  --compile "$OUTPUT_DIR" --platform macosx --minimum-deployment-target 15.0 \
  --app-icon Gamma --output-partial-info-plist "$OUTPUT_DIR/icon-info.plist" \
  --output-format human-readable-text; then
  echo 'Could not compile Gamma.icon. Full Xcode with Icon Composer support is required.' >&2
  exit 1
fi
codesign --force --sign - --timestamp=none "$OUTPUT_DIR/GAMMALauncher"
