# Changelog

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
