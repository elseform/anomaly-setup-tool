#!/usr/bin/env python3
"""Identify the source and toolchain used to assemble the local app bundle."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def toolchain_identity():
    commands = {
        "swift": ["swiftc", "--version"],
        "xcode": ["xcodebuild", "-version"],
        "sdk_path": ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
        "sdk_version": ["xcrun", "--sdk", "macosx", "--show-sdk-version"],
        "actool": ["xcrun", "--find", "actool"],
    }
    identity = {
        name: subprocess.check_output(command, text=True).strip()
        for name, command in commands.items()
    }
    identity["swift_path"] = str(Path(shutil.which("swiftc")).resolve())
    identity["environment"] = {
        name: os.environ.get(name)
        for name in ("DEVELOPER_DIR", "SDKROOT", "TOOLCHAINS")
    }
    return identity


def fingerprint(root, toolchain):
    # Include directory membership and file contents: timestamps cannot identify
    # removed resources, or a checkout that preserves old modification times.
    paths = [root / "build.sh"]
    for folder in ("sources", "scripts"):
        paths.append(root / folder)
        paths.extend((root / folder).rglob("*"))
    inputs = {}
    for path in sorted(paths):
        relative = path.relative_to(root).as_posix()
        if "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        if path.is_symlink():
            inputs[relative] = {"link": str(path.readlink())}
            if path.is_file():
                inputs[relative]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        elif path.is_file():
            inputs[relative] = {
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "mode": path.stat().st_mode & 0o777,
            }
        elif path.is_dir():
            inputs[relative] = {"directory": True}
    return {"format": 1, "inputs": inputs, "toolchain": toolchain}


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    print(json.dumps(fingerprint(root, toolchain_identity()), sort_keys=True, indent=2))
