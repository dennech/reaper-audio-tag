# Troubleshooting

## The script says ReaImGui is missing

- Open ReaPack inside REAPER.
- Install `ReaImGui: ReaScript binding for Dear ImGui`.
- Restart REAPER.

## The script asks to run bootstrap

- Run `scripts/bootstrap.command`.
- Confirm that `config.json` exists in the REAPER user data directory.
- Do not point the script at a system Python manually; it expects the managed runtime under `Data/reaper-panns-item-report/runtime/venv`.
- For development-only editable installs, run `scripts/bootstrap_runtime.sh --dev`.

## The runtime falls back to CPU

- On Apple Silicon, this is expected if `MPS` is unavailable or unstable.
- The runtime intentionally prefers a safe fallback over a crash.

## The model download fails

- Check your internet connection.
- Delete the partially downloaded checkpoint from the runtime model directory.
- Run `scripts/bootstrap.command` again.

## The selected item is rejected

- Make sure exactly one item is selected.
- Make sure the active take is audio, not MIDI.

## The tags feel too generic

- The current runtime does clip-level tagging only.
- Audio is downmixed to mono and resampled to `32 kHz` before inference.
- The report is best used as a fast cueing tool, not as a precise event detector.
