# Changelog

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
