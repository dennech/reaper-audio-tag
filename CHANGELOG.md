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
- Reworked emoji rendering around ReaImGui system-font fallback and added an `Icons: Auto / Emoji / Symbols` selector for compact report styling.
