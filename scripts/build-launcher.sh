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
  "$ROOT_DIR"/sources/GAMMALauncher/*.swift "$GENERATED_DIR/BuildInfo.swift" -o "$OUTPUT_DIR/GAMMALauncher"
if ! xcrun actool "$ROOT_DIR/sources/GAMMALauncher/Resources/Gamma.icon" \
  --compile "$OUTPUT_DIR" --platform macosx --minimum-deployment-target 26.0 \
  --app-icon Gamma --output-partial-info-plist "$OUTPUT_DIR/icon-info.plist" \
  --output-format human-readable-text; then
  echo 'Could not compile Gamma.icon. Full Xcode with Icon Composer support is required.' >&2
  exit 1
fi
codesign --force --sign - --timestamp=none "$OUTPUT_DIR/GAMMALauncher"
