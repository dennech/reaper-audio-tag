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
