# REAPER PANNs Item Report

`REAPER PANNs Item Report` is a REAPER action for quick clip-level audio inspection. It exports the currently selected audio item, downmixes it to mono, resamples it to `32 kHz`, runs local `PANNs Cnn14` tagging through a managed Python runtime, and shows a compact in-DAW report with highlights, top detected tags, backend status, and a details mode.

v1 intentionally stays narrow: macOS first, one selected audio item at a time, and `clipwise audio tagging` only. It is a practical analysis helper for fast spot checks, not a timeline event detector.

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
   - backend and timing status
   - a detailed view with top predictions

## Minimum Requirements

- REAPER `7.x`
- `ReaImGui` installed in REAPER
- macOS Apple Silicon or Intel Mac
- Python `3.11`
- Enough disk space for the runtime environment and the PANNs checkpoint

## Quick Start

1. Clone this repository.
2. Run [`scripts/bootstrap.command`](scripts/bootstrap.command) once.
3. In REAPER, load [`reaper/PANNs Item Report.lua`](reaper/PANNs%20Item%20Report.lua) into the Actions list.
4. Select exactly one audio item.
5. Run `PANNs Item Report`.

If you are installing from the public release, downloading the source archive and running `scripts/bootstrap.command` is enough. Cloning is only needed for development.

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
- The checkpoint is verified before use and is stored outside Git in the REAPER user data directory.
- The repository history was sanitized to remove accidentally committed local paths. The GitHub owner login remains part of the repository URL because the project stays under the current account.

## Notes

- The project vendors the official PANNs model code needed for `Cnn14` loading.
- The large model checkpoint is downloaded into the user REAPER data directory and is not committed to Git.
- The first release is intentionally conservative: reliability and fallback behavior are prioritized over maximum acceleration.
- The report is clip-level tagging guidance, not event detection or timeline localization.
