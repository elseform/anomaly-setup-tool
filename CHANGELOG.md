# Changelog

## 0.96 — 2026-09-30

### Main improvements

- Renamed from GAMMA Setup Tool to Anomaly Setup Tool. The app is `Anomaly Setup Tool.app`, the backend
  is `anomaly-setup-engine`, and the wrapper launcher is `AnomalyLauncher`. Engines now come from
  `elseform/anomaly-wine-engine` (`engine-cx26-w11-anomaly-<N>` releases, archives named
  `CX26-W11-ANOMALY-<N>.tar.xz`); engines published under the GAMMA name are no longer recognized. Wrapper
  settings use `ANOMALY_*` names in `app.env` (for example `ANOMALY_GRAPHICS_BACKEND`), new wrappers get the
  bundle identifier `com.elseform.anomaly.wine-engine.<name>`, and the default wrapper name is `Anomaly`
  (`stalker-anomaly` in the wizard). Logs, caches and MO2 backups moved to `anomaly-setup-tool` folders.
  Wrappers created by earlier versions keep running with their own launcher and engine copy; create new
  ones with this version. The MO2 location saved by the wizard starts empty, because settings moved to the
  new `anomaly-setup-tool` folder.
- The setup engine's mount option is now `--drive-root` (JSON key `driveRoot`, formerly `--install-root` /
  `installRoot`): the host directory that `G:` maps to. It is the parent of the MO2 instance, and no folder
  name is assumed for either. The interactive wizard's default executable path is `bin/AnomalyDX11.exe`.
- Added launch tiles for ModOrganizer, Anomaly DX11 / DX11 (AVX), and custom executables. Under
  **Executables** any number of custom executables can be added, each with a renamable tile, its own startup
  arguments, and a − button to remove it. Startup arguments are never passed to Mod Organizer.
- **Reset to Defaults…** moved to **About**.
- The launcher stays open and locks its controls until the launched program exits.
- New wrappers use the setup tool's icon.
- Replaced the Sikarugir wrapper pipeline with the `anomaly-wine-engine` engine archive
  (CrossOver 26.3 / Wine 11 with DXMT), driven by this tool's own
  `interactive_setup.py`. The wizard no longer installs Homebrew casks or resolves
  Winetricks itself; the engine archive carries the graphics backend and a pinned list of
  the Visual C++ and DirectX files it needs, which are downloaded from Microsoft's own
  installers during setup and cached.
- Requires an Apple Silicon Mac running macOS 26 or newer, as do the wrappers it creates.
- `Save setup log` now writes a log to `~/Library/Logs/anomaly-setup-tool/`.
- The graphics backend is DXMT. D3DMetal is no longer bundled, and the renderer,
  display-resolution, and drive-mapping options are gone with the pipeline that used
  them — the engine mounts both `Z:` and `G:` on its own.
- Setup progress is now reported directly from the engine script rather than parsed out
  of its console output.
- The bundled ModOrganizer `usvfs` files are only written into a folder that contains
  `ModOrganizer.exe`; a custom launch executable elsewhere no longer receives them. MO2's
  own copies that differ are backed up to `anomaly-setup-tool-backups/usvfs-<timestamp>/`
  in the MO2 folder before being replaced.
- With no local archive selected, setup always downloads the newest published
  `anomaly-wine-engine` release, verifies its checksum, and caches it. A local
  `.tar.xz` archive can be selected instead and is used as is.
- Engine archives are `.tar.xz`, which macOS unpacks without extra tools. `.tar.zst`
  archives and the `zstd` requirement are gone; releases published only as `.tar.zst`
  are skipped by the automatic download.
- A failed setup no longer deletes a Wine prefix or settings file left in
  `~/Library/Application Support/<app name>/` by an earlier wrapper of the same name.
- A failed ModOrganizer USVFS update after the wrapper is built is reported as a warning
  instead of failing an otherwise working setup.
- The setup checklist follows the order the steps actually run in, the progress bar
  follows the steps, and the last lines of setup output are no longer lost when setup
  fails.
- New apps start with Blit Encoder Merging (`DXMT_REORDER_BLITS`), Release Shader IR
  (`d3d11.releaseShaderIR`) and Force SDR Output (`dxgi.forceSDR`) on, next to Clamp NaN
  Samples To Zero. V-Sync starts on Auto, which follows the game's own V-Sync setting.
  Frame Limiter, Preferred Max Frame Rate and the Metal HUD Overlay stay off. Existing apps
  keep their settings.
- Added **Frame Limiter** (`DXMT_FRAME_LIMITER`) with a preferred frame rate or half-refresh-rate
  target. Requires a DXMT release that supports it.
- Added GPU frame capture, Metal API validation, and Metal shader validation controls, all off
  by default. Frame capture also requires a capture executable.
- Reorganized settings into a resizable window with sidebar categories and changed-setting badges.
- Added an About page showing launcher, engine, and DXMT versions, with GitHub and GAMMA Discord links.
- Simplified the setup wizard with grouped forms, automatic app naming, and executable selection
  on the welcome page. **Create wrapper** starts setup from the options page.
- Setup shows whether ModOrganizer's USVFS files need updating and reports the result on completion.

### Fixes

- Quitting the setup tool while a wrapper is being created now asks first, then stops setup and removes the
  unfinished wrapper instead of leaving it running in the background. The setup tool opens a single window.
- The wrapper name is trimmed before it is handed to setup, so the wrapper is created exactly where the wizard
  says it will be.
- In the launcher, closing or quitting after a failed save offers to discard the unsaved changes instead of
  refusing to close, and the error now shows on the About page too.
- A launch that fails right after starting now shows an error pointing to `launcher.log`.
- Startup arguments are split on spaces only: a `*` or `?` is passed to the program as it is, and quotes are
  not supported. This applies to wrappers created with this version.
- `app.env` lines you edited by hand that use `$VAR` or `` `command` `` are kept as written instead of being
  rewritten as literal text, and commented-out executable lines stay commented.
- An oversized `ANOMALY_CUSTOM_EXE_COUNT` in `app.env` no longer makes the launcher hang.
- Engine releases no longer need a `.sha256` file next to the archive; the checksum comes from the manifest.

### Removals

- Removed the bundled GPTK4 D3DMetal payload, the bundled DirectX redistributable DLLs,
  and `recommended-settings.json`. None of them had a consumer left after the pipeline
  change.
- Removed the launch-flags field. Launch arguments belong to the wrapper and are set in
  its Configurator.
- Removed the D3DMetal backend option from `interactive_setup.py` (backend prompt,
  `--backend`/`--dxmt-only`, launcher branches, D3DMetal settings and the d3d10
  override); wrappers always use DXMT. Removed the setup-time winetricks `verbs`
  runtime mode (`--runtime-mode`), which no DXMT-only engine could reach; the wrapper's
  own `Contents/MacOS/winetricks` launcher is unchanged.

## 0.86 — 2026-08-07

### Main improvements

- Dropped the `stalker-gamma-cli` requirement: any GAMMA installation works as long as it has `ModOrganizer.exe`.
- Reworked the setup flow to make creating a wrapper more direct: choose an app name, locate the GAMMA installation, and use the recommended settings or review the advanced options.
- Added bundled GPTK4 D3DMetal files and made D3DMetal the recommended renderer.
- Updated the recommended Wine environment to Sikarugir Wine 10 and bundled the ModOrganizer `usvfs` files used by the wrapper.
- Added clearer advanced controls for the Wine engine, renderer, display resolution, and drive mapping.
- Added support for launching another Windows executable with optional launch flags.
- Added a Finder shortcut for opening the wrapper configuration app.
- Reduced repeated downloads by reusing cached Sikarugir and Winetricks files when available.
- Improved setup review, progress reporting, completion details, and error guidance.
- Added an optional detailed setup log for troubleshooting.
- Updated the managed Winetricks checksums for the current `vcrun2026` redistributables so repeat wrapper creation can reuse cached payloads.

### Safety and behavior

- Setup now creates new wrappers only and will not inspect, modify, or overwrite an existing app.
- The selected GAMMA installation is checked for `ModOrganizer.exe` before setup begins.
- The standard setup uses Wine's normal `Z:` drive mapping; an optional `G:` mapping remains available for installations that already rely on it.
- Removed the DXMT and DXVK tuning options, HUD toggles, MoltenVK fast math, and the mouse input compatibility toggle; a `Configure` shortcut is created beside the wrapper instead.
- D3DMetal shader fixes, including the reflex reticle fix, are no longer bundled. They are published separately at <https://github.com/elseform/gamma-mods/releases/latest>.

Earlier releases and their notes are available on the GitHub Releases page.
