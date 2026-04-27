# Changelog

## 0.4.8

- Added `Write Tags to Project`, a one-click writeback action that saves the analyzed tags into the selected item notes and creates or updates a matching project region.
- The generated item notes preserve existing user notes and replace only the managed `REAPER Audio Tag` block on repeated writes.
- Added selection-safety and region-idempotency checks so repeated writes do not duplicate plugin regions or overwrite user-created regions.

## 0.4.7

- Fixed backend lookup on modern REAPER macOS builds that report `macOS-*` instead of the older `OSX*` value, preventing the plugin from falling back to the stale generic backend path.
- The model/setup diagnostics now show the detected REAPER OS and the full backend candidate list, making ReaPack install path mismatches visible immediately.
- Backend setup errors are now shown as warnings even when the ONNX model file is already downloaded and valid.

## 0.4.6

- Fixed macOS ReaPack backend installation by publishing both Apple Silicon and Intel backend assets with the supported `darwin` platform filter.
- The Lua action now chooses the matching macOS backend by local CPU architecture, while keeping fallback candidates for repaired or partially updated installs.
- Added regression coverage so unsupported `darwin-arm64` ReaPack package metadata cannot return unnoticed.

## 0.4.5

- Release automation now copies and verifies the ONNX model asset automatically, so a tag cannot ship without the first-run model download target.
- ReaPack runtime lookup now prefers platform-specific backend assets over stale generic fallback binaries.
- The REAPER window now shows the plugin version, and reports show CPU/GPU compute mode instead of internal backend names.

## 0.4.4

- Hardened macOS CoreML startup so the backend redirects stale unsafe cache paths with spaces to `~/Library/Caches/reaper-audio-tag/coreml-cache`, preventing CPU fallback when REAPER keeps an older Lua action instance alive after update.
- Added regression coverage for CoreML/DirectML provider selection, release tag SHA guards, model download failures, checksum cleanup, and ReaPack package surface.

## 0.4.3

- Fixed CoreML falling back to CPU on macOS by moving the CoreML cache to `~/Library/Caches/reaper-audio-tag/coreml-cache`, avoiding a packaged ONNX Runtime/CoreML path bug with `Application Support`.
- Kept the first-run ONNX model download flow and release assets unchanged.

## 0.4.2

- Simplified the first-run ONNX model download screen so users see one clear status, model size, and the main download action without repeated technical messages.
- Fixed macOS HTTPS certificate failures in the packaged backend downloader by using a bundled trusted CA bundle for GitHub Release downloads.
- Reworded download failures into user-facing messages and kept raw exception details in diagnostics/logs for troubleshooting.

## 0.4.1

- Rebuilt release assets from the exact release tag so GitHub source archives and uploaded backend binaries are reproducible again.
- Fixed Intel macOS backend packaging by allowing the ONNX Runtime version currently available for macOS x86_64.
- Hardened manual release workflow dispatch so it checks out the requested tag and refuses to upload assets built from a different commit while keeping the first-run ONNX model download flow unchanged.

## 0.4.0

- Replaced the separate Configure/Python setup flow with a simple ReaPack-first flow: install the package, run `REAPER Audio Tag`, click `Download Model`, then analyze audio.
- Switched runtime execution to a self-contained ONNX backend installed as platform-specific release assets, with CoreML on macOS, DirectML on Windows, and CPU fallback.
- Removed the public Configure and Setup actions from the ReaPack package surface; public actions are now only `REAPER Audio Tag` and `REAPER Audio Tag - Debug Export`.
- Changed the model from the manual `.pth` checkpoint flow to the release asset `cnn14_waveform_clipwise_opset17.onnx`, verified by SHA-256 after download.
- Rewrote public install and troubleshooting docs so Python, venvs, FFmpeg, and manual model selection are no longer part of the user install path.

## 0.3.8

- Removed `Save and Run` from `REAPER Audio Tag: Configure` so Configure only checks and saves settings.
- Kept inference launch exclusively in the main `REAPER Audio Tag` action, reducing accidental analysis starts from the configuration screen.
- Added Lua regression coverage to ensure Configure cannot call `start_analysis()` while the main analysis flow and runtime launcher remain covered.

## 0.3.7

- Fixed REAPER-side runtime startup by replacing the fragile direct `ExecProcess` launch with a per-job shell launcher that handles spaces, Unicode paths, and writes early launcher diagnostics into `runtime.log`.
- Simplified `Configure` so the Python field accepts either a venv folder or a concrete `python`/`python3.11` executable, with advanced runtime/config paths hidden below the main setup fields.
- Strengthened Lua coverage with an install-realistic runtime launch smoke test that starts a fake runtime from a path with spaces and waits for `result.json`, preventing silent “Listening...” stalls from passing tests.

## 0.3.6

- Fixed ReaPack `data` handling by making the canonical shipped runtime path `REAPER/Data/reaper-panns-item-report/runtime/src/...` instead of looking inside `Scripts/...`.
- Kept one-release compatibility with the accidental legacy install path `REAPER/Data/runtime/src/...` from `v0.3.4`, so existing users can still validate and run before reinstalling.
- Removed the leftover deprecated setup shim completely and tightened install-realistic coverage around the real ReaPack `data` layout.

## 0.3.4

- Fixed fresh ReaPack installs by moving the shipped runtime source into the canonical package tree under `reaper/runtime/src/...`.
- Matched the Lua runtime lookup and `Configure` validation to the real installed layout, so correct installs no longer fail with a false incomplete-package warning.
- Added install-realistic packaging regression coverage for `app_paths`, `index.xml`, and the published runtime file paths.

## 0.3.3

- Fixed GitHub Actions `tests / macos-tests` by correcting the Ruby `Gem.user_dir` path setup and installing `pandoc` before `reapack-index --check`.
- Kept `REAPER Audio Tag: Configure` as the only public setup path, while clearly relegating the remaining bootstrap scripts and runtime bootstrap CLI/docs to internal developer and recovery use.
- Removed the obsolete root-level `security_best_practices_report.md` file and finished the public cleanup around the transparent manual ReaPack install flow.

## 0.3.2

- Fixed the ReaPack package so fresh installs include `runtime/src/reaper_panns_runtime/...` instead of only the Lua files under `reaper/...`.
- Removed `REAPER Audio Tag: Setup` from the public ReaPack action surface and cleaned out the remaining installer-era runtime/setup glue from the active product path.
- Improved `Configure` with clearer file-level guidance for the Python executable and model checkpoint, deterministic path prefill, and an actionable incomplete-package message for outdated ReaPack installs.
- Renamed the optional Terminal helper to `scripts/create_local_venv_macos.sh` so the manual setup story no longer reads like an in-REAPER installer flow.
- Fixed GitHub Actions ReaPack metadata validation so `reapack-index` is found reliably on the macOS runner.

## 0.3.1

- Bumped the ReaPack package version so fresh installs and updates no longer reuse the stale `0.3.0` action surface.
- Hid `REAPER Audio Tag: Setup` from the public ReaPack action list while keeping the file installed as a compatibility shim that redirects into `Configure`.
- Added explicit ReaPack package author/about metadata so the published package shows the maintainer and the transparent manual setup model inside ReaPack.

## 0.3.0

- Replaced the public in-REAPER installer flow with a transparent manual macOS setup flow centered on `REAPER Audio Tag: Configure`.
- Added explicit Python-path and model-path validation inside REAPER, including Python `3.11` checks, required-import checks, model filename checks, and model checksum verification.
- Switched the Lua side to run the shipped Python runtime source via the configured Python executable and `PYTHONPATH`, instead of relying on release-manifest downloads or bundled runtime installation.
- Added an optional Terminal-only helper script `scripts/setup_runtime_macos.sh` for creating a venv and installing the pinned Python dependencies without hiding those steps inside REAPER.
- Reworked the ReaPack package metadata so it ships the project Python source tree as plain files, added `REAPER Audio Tag - Configure.lua`, and turned the old setup entrypoint into a deprecated compatibility stub that only redirects to Configure.
- Rewrote the English and Russian README/install/troubleshooting docs around the new trust model: manual Python install, manual dependency install, manual model download, and no hidden network activity in the normal public flow.

## 0.2.0

- Added a ReaPack-first distribution layer with repo-tracked `.reapack-index.conf`, generated `index.xml`, and ReaPack package metadata on the main Lua action.
- Added a new public `REAPER Audio Tag: Setup` action that installs version-pinned bundled runtime releases into the REAPER data directory instead of sending normal users through `bootstrap.command`.
- Added Lua setup/install orchestration with architecture detection, ReaImGui guidance, release-manifest lookup, checksum verification, staging, rollback, and idempotent reruns.
- Added release automation scaffolding for macOS arm64 and x86_64 runtime bundles, architecture-specific manual installer ZIPs, and a combined release manifest with checksums.
- Reworked the public install and troubleshooting docs so the recommended flow is now `ReaPack -> REAPER Audio Tag: Setup -> REAPER Audio Tag`, with `bootstrap.command` kept as a developer and recovery path.

## 0.1.0

- Initialized the repository, bootstrap flow, Lua action, Python runtime, and bilingual docs.
- Fixed runtime backend selection so `auto` now follows the documented `MPS -> CPU` fallback policy.
- Replaced max-only long-file aggregation with top-k mean plus segment support metadata.
- Normalized the Lua <-> Python JSON contract and aligned tests with the production response shape.
- Softened report wording to present clip-level tags more honestly and exposed attempted backend diagnostics.
- Switched bootstrap to a regular packaged install by default, keeping editable mode for `--dev`.
- Reworked README/onboarding copy for the public macOS-first `v0.1.0` release flow.
- Added Python, Lua, and integration tests plus GitHub Actions CI.
- Expanded the compact report to show more cues and tags, added a clearer `Another` rerun flow, and upgraded the fallback icon style for non-emoji ReaImGui setups.
- Added safe cleanup for temporary export WAVs and finished job artifacts so the script no longer leaves stale app-owned files behind.
- Documented rerun workflow, export diagnostics, and temporary-file cleanup behavior in the English and Russian docs.
- Replaced unreliable mixed-text emoji rendering and custom sticker art with bundled Noto Emoji image assets, added a reproducible asset generator, and kept a plain-text fallback when image handles are unavailable.
- Clarified the Noto Emoji asset licensing split by adding Apache 2.0 text for the vendored PNG image resources and explicit third-party attribution notes for the bundled image pipeline.
- Moved the preferred checkpoint cache to repo-local `.local-models/` in writable checkouts, kept `.gitignore` protection, and preserved REAPER data-dir fallback for non-writable or atypical environments.
- Reworked selected-item export into an incremental async Lua session so opening the report no longer blocks REAPER while the temporary WAV is being prepared.
- Changed the main report to show the full tag ranking as wrapped pill chips and normalized chip colors across `Strong`, `Solid`, `Possible`, and `Low` buckets.
- Removed the temporary on-screen diagnostics block, debug-log path readout, and report-window log buttons after the REAPER slowdown investigation stabilized.
- Rebranded the public action to `REAPER Audio Tag`, added backward-compatible legacy script shims for existing REAPER action paths, and mapped `Plop` plus liquid-family labels to a bundled bubble icon.
- Added a tracked README hero screenshot under `docs/images/` so the public repository landing pages show the current macOS report UI.
- Added a runtime-mocked Lua regression test that executes the legacy action wrappers and verifies they forward to the renamed script entrypoints on both POSIX and Windows-style paths.
- Reworked the public install docs so normal users can install from a GitHub release ZIP without `git clone`, with explicit ReaPack/ReaImGui steps and a transparent explanation that `bootstrap.command` downloads and verifies the PANNs model automatically.
- Clarified the install docs with explicit ReaPack placement instructions and concrete Python 3.11 installation guidance for macOS users.
- Clarified that the current public distribution path is the GitHub release source ZIP, because there is not yet a separate slim installer bundle or packaged release asset.
