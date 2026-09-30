#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$ROOT_DIR/dist/tests"
swiftc -parse-as-library -target arm64-apple-macosx26.0 \
  "$ROOT_DIR/sources/AnomalyLauncher/Schema.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/EnvFile.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/PathsConfig.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/EngineInfo.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/ConfiguratorModel.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/LaunchTarget.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/CustomExecutable.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/LaunchEntry.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/LaunchController.swift" \
  "$ROOT_DIR/sources/AnomalyLauncher/LauncherError.swift" \
  "$ROOT_DIR/tests/launcher/LauncherTests.swift" -o "$ROOT_DIR/dist/tests/LauncherTests"
"$ROOT_DIR/dist/tests/LauncherTests"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/python/test_wrapper.py"
