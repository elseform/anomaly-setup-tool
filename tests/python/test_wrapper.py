"""Exercise wrapper assembly and shell launching without invoking Wine."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("setup", ROOT / "sources/AnomalySetupTool/Resources/wine-engine/interactive_setup.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)
RESOURCES = ROOT / "dist/Anomaly Setup Tool.app/Contents/Resources/launcher"


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="anomaly-wrapper-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.game = self.root / "game's $literal"
        self.game.mkdir()
        (self.game / "ModOrganizer.exe").touch()
        setup._cleanup_paths.clear()
        setup._PENDING_REG.clear()

    def archive(self, legacy=False):
        tree = self.root / "wswine.bundle"
        for d in ("bin", "lib/dxmt", "lib/wine/x86_64-unix"):
            (tree / d).mkdir(parents=True, exist_ok=True)
        (tree / "bin/wine").write_text("#!/bin/sh\nexit 0\n")
        (tree / "bin/wine").chmod(0o755)
        (tree / "lib/wine/x86_64-unix/cxcompatdb.so").touch()
        if legacy:
            (tree / "share/anomaly/Configurator.app").mkdir(parents=True)
        archive = self.root / "engine.tar.xz"
        with tarfile.open(archive, "w:xz") as tf:
            tf.add(tree, arcname="wswine.bundle")
        return archive

    def args(self, archive):
        return setup.build_arg_parser().parse_args([
            "--yes", "--archive", str(archive), "--launcher-resources", str(RESOURCES),
            "--app-name", "Anomaly Test", "--app-parent", str(self.root / "apps"),
            "--drive-root", str(self.game), "--exe-rel-path", "ModOrganizer.exe"])

    def assemble(self, legacy=False):
        args = self.args(self.archive(legacy))
        with patch.object(Path, "home", return_value=self.home), patch.object(setup, "run", return_value=(0, "")), patch.object(setup, "install_redistributables", return_value=[]), patch.object(setup, "log"), patch.object(setup, "artifact_event"):
            setup.run_setup(args)
        return self.root / "apps/Anomaly Test.app"

    def test_assembly_without_configurator(self):
        self.check_assembly(self.assemble())

    def test_assembly_with_legacy_configurator(self):
        self.check_assembly(self.assemble(True))

    def check_assembly(self, app):
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleExecutable"], "AnomalyLauncher")
        self.assertEqual(info["CFBundleIconName"], "SetupTool")
        self.assertEqual(info["CFBundleIconFile"], "SetupTool")
        self.assertEqual(info["LSMinimumSystemVersion"], "26.0")
        self.assertFalse((app / "Contents/Resources/Configurator.app").exists())
        self.assertEqual(len(list(app.parent.iterdir())), 1)
        for name in ("SetupTool.icns", "Assets.car"):
            self.assertEqual((app / "Contents/Resources" / name).read_bytes(), (RESOURCES / name).read_bytes())
        for name in ("launcher", "winecfg", "winetricks"):
            subprocess.run(["/bin/bash", "-n", str(app / "Contents/MacOS" / name)], check=True)
        config = self.home / "Library/Application Support/Anomaly Test/app.env"
        shell = subprocess.check_output(["/bin/bash", "-c", 'source "$1"; printf "%s" "$EXE_RUN_DIR"', "test", str(config)], text=True)
        self.assertEqual(shell, str(self.game))
        self.assertIn("d3d11.sampleNaNToZero=true;", config.read_text())
        self.assertIn("d3d11.releaseShaderIR=true;dxgi.forceSDR=true;", config.read_text())
        self.assertIn("export DXMT_REORDER_BLITS=1\n", config.read_text())
        self.assertIn("d3d11.displaySync=auto;", config.read_text())
        self.assertIn("export MTL_HUD_ENABLED=0\n", config.read_text())

    def test_missing_resources_fail_before_outputs(self):
        args = self.args(self.archive())
        args.launcher_resources = str(self.root / "absent")
        with self.assertRaises(setup.SetupError), patch.object(setup, "run", side_effect=AssertionError("must not invoke external commands")):
            setup.run_setup(args)
        self.assertFalse((self.root / "apps").exists())
        self.assertEqual(setup._cleanup_paths, [])

    def test_failed_assembly_preserves_previous_support(self):
        args = self.args(self.archive())
        support = self.home / "Library/Application Support/Anomaly Test"
        support.mkdir(parents=True)
        original = support / "app.env"
        original.write_text("original settings")
        with patch.object(Path, "home", return_value=self.home), patch.object(setup, "run", side_effect=setup.SetupError("stub failure")), patch.object(setup, "log"):
            with self.assertRaises(setup.SetupError):
                setup.run_setup(args)
            setup._cleanup_partial_wrapper()
        self.assertEqual(original.read_text(), "original settings")
        self.assertFalse((self.root / "apps/Anomaly Test.app").exists())

    def test_helper_suppresses_only_default_mo2_arguments(self):
        app = self.assemble()
        stubdir = self.root / "stubs"
        stubdir.mkdir()
        for name, text in {"arch": '#!/bin/sh\nshift\nexec "$@"\n', "taskpolicy": '#!/bin/sh\nshift 4\nexec "$@"\n'}.items():
            (stubdir / name).write_text(text)
            (stubdir / name).chmod(0o755)
        wine = app / "Contents/Resources/engine/bin/wine"
        wine.write_text('#!/bin/sh\n[ "$1" = reg ] && exit 0\nprintf "%s\\n" "$@"\n')
        config = self.home / "Library/Application Support/Anomaly Test/app.env"
        env = dict(os.environ, PATH=str(stubdir) + ":/usr/bin:/bin")
        helper = app / "Contents/MacOS/launcher"
        for target, explicit, expected in [(r"G:\ModOrganizer.exe", [], []), (r"G:\MODORGANIZER.EXE", ["--explicit"], ["--explicit"]), (r"G:\AnomalyDX11.exe", [], ["-dbg", "-nointro"])]:
            config.write_text(f"export EXE_PATH={shlex.quote(target)}\nexport EXE_RUN_DIR={shlex.quote(str(self.game))}\nexport DEFAULT_GAME_ARGS='-dbg -nointro'\n")
            output = subprocess.check_output([str(helper), *explicit], env=env, text=True)
            self.assertEqual(output.splitlines(), [target, *expected])


if __name__ == "__main__":
    unittest.main()
