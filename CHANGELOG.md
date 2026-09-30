# Changelog

## 0.96 — unreleased

### Main improvements

- Renamed from GAMMA Setup Tool to Anomaly Setup Tool. The app is `Anomaly Setup Tool.app`, the backend
  is `anomaly-setup-engine`, and the wrapper launcher is `AnomalyLauncher`. Engines now come from
  `elseform/anomaly-wine-engine` (`engine-cx26-w11-anomaly-<N>` releases, archives named
  `CX26-W11-ANOMALY-<N>.tar.xz`); engines published under the GAMMA name are no longer recognized. Wrapper
  settings use `ANOMALY_*` names in `app.env` (for example `ANOMALY_GRAPHICS_BACKEND`), new wrappers get the
  bundle identifier `com.elseform.anomaly.wine-engine.<name>`, and the default wrapper name is `Anomaly`
  (`stalker-anomaly` in the wizard). Logs, caches and MO2 backups moved to `anomaly-setup-tool` folders.
  Wrappers created by earlier versions keep running with their own launcher and engine copy; create new
  ones with this version.
- The wrapper window opens on a grid of launch tiles instead of a single Launch button: ModOrganizer and two
  Mod Organizer shortcuts (Anomaly - DX11, Anomaly - DX11 (AVX)) while a ModOrganizer.exe path is set, and
  the custom executable while that path is set. **Launch options** now holds both paths; setup fills in the
  one chosen at creation and existing wrappers keep their target. Launch arguments apply to the custom
  executable only. The window title no longer shows the wrapper's name, and the bottom-bar Launch button is gone.
- The wrapper window stays open after a launch instead of closing. While the launched program runs, the whole
  window is greyed out under a "Wrapper is running" message, and it unlocks by itself when that program exits.
- New wrappers use the setup tool's icon. The green Anomaly icon artwork stays in the repository, unused.
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
- The app's settings add **Frame Limiter** (`DXMT_FRAME_LIMITER`), which paces the game itself to
  Preferred Max Frame Rate or half the display's refresh rate. Both now sit in Frame Rate &
  Sync. The limiter needs a DXMT release that includes it.
- Debugging has a **Metal: Debug** group that gathers the Performance Overlay (moved from
  Display), the frame capture settings, and new **GPU Frame Capture** (`MTL_CAPTURE_ENABLED`),
  **Metal API Validation** (`MTL_DEBUG_LAYER`) and **Metal Shader Validation**
  (`MTL_SHADER_VALIDATION`) switches. Capturing a GPU trace needs GPU Frame Capture on as
  well as a capture executable, which the window did not offer before; the executable and
  frame rows appear once capture is on. All three switches start off.
- The app's settings window is wider and resizable, with a sidebar of categories instead
  of one long list: Launch, Frame Rate & Sync, Display and Upscaling, then Performance,
  Rendering Fixes, Compatibility, Wine and Debugging under Advanced. A badge on each
  category counts the settings changed from what a new app starts with. Reset to
  Defaults and Launch sit at the bottom of the window.
- The setup tool's pages now use the same grouped forms, bottom bar and buttons as the app's
  settings window.
- The settings window has an About page with the launcher version, which always matches the
  Anomaly Setup Tool that built the app, and the engine and DXMT versions bundled in it. The
  footer links to the GitHub repository and the GAMMA Discord.

- The wizard opens on a welcome page where you select `ModOrganizer.exe` (or another
  executable) and then name the app on the same page. The name is filled in from the
  executable, with `-2`, `-3`, ... added when that app already exists. The separate review
  step is gone: **Create wrapper** starts setup from the options page, which lists what setup
  will do. Engine file,
  drive-mapping, and log options are collapsed, and wording throughout uses plain
  language instead of wrapper and engine terms.
- The name and options pages say whether ModOrganizer's `usvfs` files will be updated,
  are already up to date, or are left alone; the finish page reports what was done.
- The finish page lists next steps: where the app is, how it starts the game, and where
  its Configurator is.
- The support link is now labeled **GAMMA Discord**.

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
