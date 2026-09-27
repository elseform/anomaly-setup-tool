#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$ROOT_DIR/dist/tests"
swiftc -parse-as-library -target arm64-apple-macosx26.0 \
  "$ROOT_DIR/sources/GAMMALauncher/Schema.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/EnvFile.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/PathsConfig.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/ConfiguratorModel.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/LaunchTarget.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/LaunchController.swift" \
  "$ROOT_DIR/sources/GAMMALauncher/LauncherError.swift" \
  "$ROOT_DIR/tests/launcher/LauncherTests.swift" -o "$ROOT_DIR/dist/tests/LauncherTests"
"$ROOT_DIR/dist/tests/LauncherTests"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/python/test_wrapper.py"
