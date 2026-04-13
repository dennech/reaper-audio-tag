# REAPER Audio Tag

`REAPER Audio Tag` is a REAPER action for quick clip-level audio inspection. It exports the currently selected audio item, downmixes it to mono, resamples it to `32 kHz`, runs local `PANNs Cnn14` tagging through a managed Python runtime, and shows a compact in-DAW report with highlights, top detected tags, backend status, and a details mode.

v1 intentionally stays narrow: macOS first, one selected audio item at a time, and `clipwise audio tagging` only. It is a practical analysis helper for fast spot checks, not a timeline event detector.

<img src="docs/images/reaper-audio-tag-hero.png" alt="REAPER Audio Tag report window" width="760">

_Current REAPER Audio Tag report window on macOS with wrapped tag chips and emoji atlas icons._

## Status

- v1 target: `macOS Apple Silicon + Intel Mac`
- Windows: planned after the first macOS release
- Model scope in v1: `clipwise audio tagging` only
- UI dependency: `ReaImGui`

## What It Does

1. Exports the exact selected take region from REAPER via `CreateTakeAudioAccessor` and `GetAudioAccessorSamples`.
2. Downmixes the audio to mono and resamples it to `32 kHz` before tagging.
3. Sends a JSON request to the local Python runtime.
4. Runs PANNs inference with `MPS -> CPU` fallback on Apple Silicon, or `CPU` on Intel Mac.
5. Displays:
   - a compact summary with interesting findings
   - up to `5` top cues in the compact view
   - the full tag ranking as wrapped pill chips in the main report
   - backend and timing status
   - a detailed view with top predictions
   - an `Another` action so you can select a different item and rerun without closing the window

## Minimum Requirements

- REAPER `7.x`
- `ReaImGui` installed in REAPER
- macOS Apple Silicon or Intel Mac
- Python `3.11`
- Enough disk space for the runtime environment and the PANNs checkpoint

## Quick Start

1. Install REAPER `7.x`.
2. Make sure `ReaPack` is available in REAPER.
3. In ReaPack, install `ReaImGui: ReaScript binding for Dear ImGui`, then restart REAPER.
4. Install Python `3.11`.
5. Download the latest ZIP from the [GitHub Releases page](https://github.com/dennech/reaper-audio-tag/releases/latest).
6. Unpack it anywhere on your Mac.
7. Run [`scripts/bootstrap.command`](scripts/bootstrap.command) once.
8. In REAPER, load [`reaper/REAPER Audio Tag.lua`](reaper/REAPER%20Audio%20Tag.lua) into the Actions list.
9. Select exactly one audio item.
10. Run `REAPER Audio Tag`.

`git clone` is only needed for development. A normal user install should work from the downloaded ZIP alone.

What `bootstrap.command` does:

- creates the managed Python environment in the REAPER app data directory
- installs the packaged runtime used by the script
- downloads `Cnn14_mAP=0.431.pth` automatically
- verifies the checkpoint before enabling it
- writes the REAPER-side runtime config

Detailed setup instructions:

- English: [`docs/install.md`](docs/install.md)
- Russian: [`docs/install.ru.md`](docs/install.ru.md)

Troubleshooting:

- English: [`docs/troubleshooting.md`](docs/troubleshooting.md)
- Russian: [`docs/troubleshooting.ru.md`](docs/troubleshooting.ru.md)

## Development

- Python tests: `python3 tests/scripts/run_python_tests.py --scope python`
- Integration tests: `python3 tests/scripts/run_python_tests.py --scope integration`
- Lua tests: `lua tests/lua/run_tests.lua`

## Repository Layout

- [`reaper/`](reaper): Lua action, UI, audio export, runtime bridge
- [`runtime/`](runtime): Python runtime package, model adapter, bootstrap logic
- [`tests/`](tests): Python, Lua, and integration coverage
- [`scripts/`](scripts): bootstrap helpers

## Security & Privacy

- The runtime uses only the managed REAPER-side virtual environment and does not trust an external Python path from `config.json`.
- The checkpoint is verified before use and is stored outside Git. In a normal writable checkout, bootstrap prefers `repo_root/.local-models/`.
- The repository history was sanitized to remove accidentally committed local paths. The GitHub owner login remains part of the repository URL because the project stays under the current account.

## Notes

- The project vendors the official PANNs model code needed for `Cnn14` loading.
- The large model checkpoint is cached locally and is not committed to Git. In development checkouts it now prefers `.local-models/`, with a REAPER data-dir fallback for atypical environments.
- The first release is intentionally conservative: reliability and fallback behavior are prioritized over maximum acceleration.
- The report is clip-level tagging guidance, not event detection or timeline localization.
- Export preparation now runs incrementally on the Lua side before Python inference starts, so opening the report stays responsive on longer selected items.
- The script cleans up only its own temporary export WAVs, job files, and logs inside `Data/reaper-panns-item-report/{tmp,jobs,logs}`. It never deletes the original source audio or project media.
- The compact report now uses bundled Noto Emoji PNG assets instead of system text emoji or custom sticker art, so tag chips stay consistent across REAPER/ReaImGui setups.
- Tag chips use a stable bucket palette: `Strong` green, `Solid` purple, `Possible` yellow, and `Low` red.
- The vendored emoji source lives under `reaper/assets/noto-emoji/`, and `scripts/generate_report_emoji_assets.py` regenerates the self-contained Lua bundles when those assets change.
- The project vendors Noto Emoji image resources, not the font files. For the bundled PNG assets, keep the Apache 2.0 notice under `reaper/assets/noto-emoji/LICENSE-APACHE-2.0.txt` and the attribution note in `THIRD_PARTY_NOTICES.md`.
- If the image path is unavailable in a specific session, the UI falls back to plain text labels only. Analysis behavior is unchanged.
- For export diagnostics without running the model, use `reaper/REAPER Audio Tag - Debug Export.lua`.
