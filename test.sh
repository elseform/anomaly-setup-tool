#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/dist/tests"
SWIFT_TEST_BINARY="$BUILD_DIR/SetupConfigurationTests"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR"

printf '==> Running Swift tests\n'
swiftc \
  -target arm64-apple-macosx26.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$ROOT_DIR/sources/AnomalySetupCore/"*.swift \
  "$ROOT_DIR/sources/AnomalySetupTool/AppSettingsStore.swift" \
  "$ROOT_DIR/sources/AnomalySetupTool/SetupConfiguration.swift" \
  "$ROOT_DIR/sources/AnomalySetupTool/SetupStatusTone.swift" \
  "$ROOT_DIR/tests/swift/AppSettingsStoreTests.swift" \
  "$ROOT_DIR/tests/swift/SetupConfigurationTests.swift" \
  "$ROOT_DIR/tests/swift/RedistInstallerTests.swift" \
  "$ROOT_DIR/tests/swift/EngineArchiveTests.swift" \
  "$ROOT_DIR/tests/swift/SetupStatusToneTests.swift" \
  "$ROOT_DIR/tests/swift/USVFSUpdaterTests.swift" \
  "$ROOT_DIR/tests/swift/ScriptOutputRelayTests.swift" \
  "$ROOT_DIR/tests/swift/main.swift" \
  -o "$SWIFT_TEST_BINARY"
"$SWIFT_TEST_BINARY"

printf '\n==> Running build smoke test\n'
"$ROOT_DIR/build.sh" bundle >/dev/null

printf '\n==> Checking the launcher carries the setup tool version\n'
TOOL_VERSION="$(sed -n 's/^APP_VERSION="\(.*\)"$/\1/p' "$ROOT_DIR/build.sh")"
if ! strings -a "$ROOT_DIR/dist/Anomaly Setup Tool.app/Contents/Resources/launcher/AnomalyLauncher" | grep -qx "$TOOL_VERSION"; then
  echo "AnomalyLauncher does not carry version $TOOL_VERSION" >&2
  exit 1
fi

printf '\n==> Building Swift setup engine for CLI tests\n'
swiftc \
  -target arm64-apple-macosx26.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$ROOT_DIR/sources/AnomalySetupCore/"*.swift \
  "$ROOT_DIR/sources/AnomalySetupEngine/main.swift" \
  -o "$BUILD_DIR/anomaly-setup-engine"

printf '\n==> Running Swift setup engine CLI tests\n'
"$BUILD_DIR/anomaly-setup-engine" --help >/dev/null
bash "$ROOT_DIR/tests/shell/anomaly_setup_engine_tests.sh" "$ROOT_DIR" "$BUILD_DIR/anomaly-setup-engine"

bash "$ROOT_DIR/tests/launcher/run.sh"

printf '\nAll tests passed.\n'
