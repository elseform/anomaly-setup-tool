# Anomaly Setup Tool

Status: current development version, 0.96 (`dev` branch).

Native macOS tool for creating a Wine `.app` wrapper around an existing S.T.A.L.K.E.R. Anomaly installation, using [anomaly-wine-engine](https://github.com/elseform/anomaly-wine-engine) and DXMT. It does not install Anomaly.

This README describes the current source. Published builds are available on the [Releases page](https://github.com/elseform/anomaly-setup-tool/releases); check the version and release notes before following these instructions with an older build.

## Requirements

- An Apple Silicon Mac running macOS 26 or newer, with Rosetta 2 for the Wine engine.
- An existing Anomaly installation and its `ModOrganizer.exe`, or another Windows executable to launch.
- Python 3 available to setup. The backend checks `/usr/bin/python3`, `/opt/homebrew/bin/python3`, then `/usr/local/bin/python3`.
- Internet access for automatic engine resolution and missing runtime downloads. For offline setup, select a local engine archive and provide or cache the runtime files described below.

## Create a Wrapper

Extract the downloaded setup-tool archive and open `Anomaly Setup Tool.app`, or [build the current source](#build-and-test). Builds made by `build.sh` are ad-hoc signed, not notarized.

1. On the first page, click **Choose…** and select `ModOrganizer.exe` from your existing installation. You can select another `.exe` as the launch target instead. The page then says whether setup will update ModOrganizer's `usvfs` files.
2. The app name is filled in from the selected executable (`ModOrganizer` for `ModOrganizer.exe`), with `-2`, `-3`, and so on added if an app of that name already exists in `~/Applications`. Change it if you like, then click **Continue**.
3. On **Options**, the engine is downloaded automatically; expand **Use a local engine file** to choose a local `.tar.xz` archive instead. Optionally expand **Windows components** to see which Microsoft runtime files are already present or choose a folder containing downloaded copies. **Advanced** holds the drive mappings and **Save a setup log**; leave the log enabled for troubleshooting.
4. Click **Create wrapper**.
5. Open the created app from Finder. It opens on a grid of launch tiles: **ModOrganizer**, **Anomaly - DX11** and **Anomaly - DX11 (AVX)** (Mod Organizer shortcuts) while a ModOrganizer.exe path is set, and a tile for the custom executable while that path is set. Click a tile to launch it; the window quits after handing off to the launch process. Adjust settings, or set either path, from the sidebar first.

Setup checks the selected executable exists; it does not validate the contents or health of the Anomaly installation.

## Engine Selection and Downloads

With **Engine archive** empty, setup always uses the newest `engine-*` release from `elseform/anomaly-wine-engine`, ordered by engine version. It downloads the archive and verifies its SHA-256 against the release manifest. Cached archives are checked by checksum before reuse.

A local archive is used exactly as selected, with no version check. Automatic selection needs access to the release listing and manifest even when the archive is cached; offline, select a local archive.

The wizard creates DXMT wrappers with the engine's declared runtime dependencies. It has no renderer, Wine-version, Winetricks-verb, or display-mode selector.

## Runtime Files and Installation Changes

The engine archive supplies the runtime manifest and fetcher. Setup obtains the declared files from checksum-pinned downloads, reusing a supplied folder before the cache. The current runtime list includes:

- `VC_redist.x64.exe` — Visual C++ 2015–2022 Redistributable.
- `directx_Jun2010_redist.exe` — DirectX End-User Runtime, June 2010.
- `d3dcompiler_47.dll` — the Microsoft compiler DLL redistributed through Mozilla's `fxc2` repository.

The engine manifest controls the actual files and checksums; selecting a folder does not bypass verification.

Setup mounts the drive root as `G:` and the host root as `Z:`. The drive root is the host directory `G:` maps to; the wizard derives it as the parent of the selected executable's containing directory, which for `ModOrganizer.exe` is the parent of the MO2 instance. Review the mapping before creating the wrapper, especially with a custom executable.

After wrapper creation, setup checks the bundled USVFS files against the selected executable's folder. It updates them only if that folder contains `ModOrganizer.exe`. Existing files that differ are backed up inside that folder under `anomaly-setup-tool-backups/usvfs-<timestamp>/` before replacement; matching files are left alone. A custom executable outside a ModOrganizer folder receives no USVFS files.

## Settings, Logs, and Caches

Each wrapper has its own Wine prefix and settings outside the app bundle:

```text
~/Applications/<app name>.app
~/Library/Application Support/<app name>/prefix/
~/Library/Application Support/<app name>/app.env
```

Setup seeds defaults with no launch arguments. The wrapper saves settings automatically, commits pending edits before launching or closing, and remains open if saving fails. **Reset to Defaults** preserves both executable paths and their working directories.

**Launch options** holds two paths: `ModOrganizer.exe` and a custom `.exe`. Setup fills in whichever one you chose when creating the wrapper; the other can be set there afterwards, and either can be cleared. The pickers accept a readable local `.exe` (the ModOrganizer picker only `ModOrganizer.exe`), using the existing `G:` mapping where possible and `Z:` otherwise. The Anomaly tiles run the Mod Organizer executables titled `Anomaly (DX11)` and `Anomaly (DX11-AVX)`, so those titles must exist in Mod Organizer's executable list. Launch arguments apply to the custom executable only and are never passed to Mod Organizer; configure game arguments in Mod Organizer itself. Wine and graphics settings still apply. Changing a path does not modify drive mappings, install runtime files, or update USVFS.

Launch output goes to `~/Library/Logs/<app name>/launcher.log`. The native UI quits after creating the launcher process; later Wine or game failures are recorded in that log. The CLI helper at `Contents/MacOS/launcher` remains available, including explicit argument forwarding.

New wrappers use the setup tool's own `SetupTool.icon` artwork. Both modern appearance assets and an `.icns` fallback are packaged. The green `Anomaly.icon` artwork stays in `sources/AnomalyLauncher/Resources/` but is not used. Existing installed wrappers are not modified.

With **Save setup log** enabled, setup events are written to:

```text
~/Library/Logs/anomaly-setup-tool/<app name>-YYYYMMDD-HHMMSS.log
```

Downloads are cached at:

```text
~/Library/Application Support/anomaly-setup-tool/cache/anomaly-wine-engine/
~/Library/Application Support/anomaly-setup-tool/cache/redist-installers/
```

For failed setup, use the detailed log and the GAMMA Discord link in the app.

## Build and Test

Building requires full Xcode with Icon Composer-capable `actool`, selected through `xcode-select`; Command Line Tools alone cannot compile `SetupTool.icon`, which is both the app's icon and the wrapper's. From the repository root:

```sh
./build.sh
```

This compiles the GUI and backend with `swiftc` for Apple Silicon and macOS 26, builds and ad-hoc signs `dist/Anomaly Setup Tool.app`, then replaces `~/Applications/Anomaly Setup Tool.app` with that build. No Xcode project or sibling engine checkout is required. The build also compiles the native wrapper UI and icon; end users need no compiler or Xcode.

- `./build.sh run` builds and runs the GUI from `dist/` without installing it.
- `./build.sh clean` removes `dist/`.
- `./test.sh` runs Swift unit tests, backend CLI integration tests, and a build smoke test. The smoke test runs `build.sh bundle`, which builds `dist/` without installing anything.

After every change to the source, run `./build.sh` so that `~/Applications/Anomaly Setup Tool.app` is a copy of the current source. `./test.sh` does not install.

Developers can set `ANOMALY_ENGINE_ARTIFACTS_DIR` in the app's environment to prefill the local archive field with the most recently modified `.tar.xz` in that directory.

### Source Layout

| Path | Responsibility |
| --- | --- |
| `sources/AnomalySetupTool/` | SwiftUI wizard, setup state, request construction, progress display, and the app's `SetupTool.icon`. |
| `sources/AnomalyLauncher/` | Native wrapper settings, target picker, launch tiles, and the unused green `Anomaly.icon`. |
| `sources/AnomalySetupCore/` | Shared models, engine release resolution, checksum verification, wrapper pipeline, and USVFS updates. |
| `sources/AnomalySetupEngine/` | `anomaly-setup-engine` CLI backend, called by the GUI through `create-wine-engine`. |
| `sources/AnomalySetupTool/Resources/wine-engine/interactive_setup.py` | Canonical wrapper-creation script, bundled by `build.sh`. |
| `tests/` | Swift unit tests and shell CLI integration tests. |

`Package.swift` defines the wizard, setup backend, and `AnomalyLauncher` executable products. `build.sh` assembles the distributable app bundle and its backend and resources.

### Launcher resources and engine compatibility

`build.sh bundle` creates `dist/Anomaly Setup Tool.app/Contents/Resources/launcher/`
with `AnomalyLauncher`, `SetupTool.icns`, `Assets.car`, and `icon-info.plist`.
The setup backend passes this directory to `interactive_setup.py` through
`--launcher-resources`; direct script callers must supply it too. Missing or
invalid resources fail before wrapper or prefix changes. Run the bundle build
before using the development CLI from SwiftPM.

The UI and icon come from setup-tool, not the engine archive. Engine archives
with or without the former `share/anomaly/Configurator.app` are accepted, subject
to the existing runtime requirements. Older setup-tool builds still require that
former archive layout; ship updated setup-tool support before publishing engines
without Configurator. No engine-version gate has been added.
