"""Regression coverage for install-without-rebuild freshness checks."""

import importlib.util
import os
from pathlib import Path
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("build_fingerprint", ROOT / "scripts/build-fingerprint.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


@pytest.fixture
def project(tmp_path):
    (tmp_path / "sources/resources").mkdir(parents=True)
    (tmp_path / "scripts").mkdir()
    (tmp_path / "build.sh").write_text("swiftc -O\n")
    (tmp_path / "scripts/build-launcher.sh").write_text("swiftc -O\n")
    (tmp_path / "sources/main.swift").write_text("print(1)\n")
    (tmp_path / "sources/resources/icon").write_bytes(b"icon")
    return tmp_path


def test_unchanged_inputs_ignore_timestamps(project):
    before = BUILD.fingerprint(project, {"swift": "test"})
    os.utime(project / "sources/main.swift", (1, 1))
    assert BUILD.fingerprint(project, {"swift": "test"}) == before


@pytest.mark.parametrize("relative", ["sources/main.swift", "build.sh", "scripts/build-launcher.sh"])
def test_changed_content_with_preserved_mtime(project, relative):
    before = BUILD.fingerprint(project, {})
    source = project / relative
    original = source.stat()
    source.write_text("changed\n")
    os.utime(source, ns=(original.st_atime_ns, original.st_mtime_ns))
    assert BUILD.fingerprint(project, {}) != before


def test_deleted_resource(project):
    before = BUILD.fingerprint(project, {})
    (project / "sources/resources/icon").unlink()
    assert BUILD.fingerprint(project, {}) != before


def test_added_resource(project):
    before = BUILD.fingerprint(project, {})
    (project / "sources/resources/new").write_bytes(b"new")
    assert BUILD.fingerprint(project, {}) != before


def test_changed_toolchain(project):
    assert BUILD.fingerprint(project, {"swift": "old"}) != BUILD.fingerprint(project, {"swift": "new"})


def test_generated_python_cache_is_ignored(project):
    before = BUILD.fingerprint(project, {})
    cache = project / "scripts/__pycache__"
    cache.mkdir()
    (cache / "build-fingerprint.pyc").write_bytes(b"cache")
    assert BUILD.fingerprint(project, {}) == before


def test_install_refuses_legacy_bundle_without_fingerprint(tmp_path):
    # Exercise the actual shell gate without invoking a compiler or touching an
    # installed app. Legacy bundles must be rebuilt once to acquire a manifest.
    (tmp_path / "build.sh").write_bytes((ROOT / "build.sh").read_bytes())
    binary = tmp_path / "dist/Anomaly Setup Tool.app/Contents/MacOS/Anomaly Setup Tool"
    binary.parent.mkdir(parents=True)
    binary.write_text("#!/bin/sh\nexit 0\n")
    binary.chmod(0o755)
    result = subprocess.run(["bash", str(tmp_path / "build.sh"), "install"], capture_output=True, text=True)
    assert result.returncode == 1
    assert "inputs or toolchain have changed" in result.stderr
