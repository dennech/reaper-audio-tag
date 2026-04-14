# Runtime

This directory contains the Python runtime package used by `REAPER Audio Tag`.

These notes are internal and developer-facing. Normal users should follow the top-level ReaPack + `Configure` installation flow, not the runtime/bootstrap commands documented here.

## CLI

- `reaper-panns-runtime bootstrap` (internal dev/recovery only)
- `reaper-panns-runtime probe`
- `reaper-panns-runtime analyze`

## Responsibilities

- runtime config for the REAPER user data directory
- backend probing with `MPS -> CPU` fallback
- PANNs `Cnn14` loading
- mono downmix + `32 kHz` preprocessing before clip-level tagging
- JSON contract handling for the Lua bridge

## Notes

- The runtime package lives under `reaper/runtime/src/reaper_panns_runtime`.
- Public users are expected to install Python, third-party dependencies, and the model file explicitly, then point `REAPER Audio Tag: Configure` at those paths.
- Development and recovery tooling can still use `bootstrap` and `.local-models/` for local checkouts.
- The fake model path exists to keep tests and contract validation lightweight.
- `scripts/bootstrap_runtime.sh` is an internal helper for development and recovery work. It is not part of the public ReaPack install story.
