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
- If you already have a report open, keep the window open, select the new item, and click `Another`.

## The compact view does not show the colorful icons

- The current build uses embedded PNG sticker icons instead of system emoji.
- If the compact chips show text without icons, the image decode/render path is unavailable in that REAPER session.
- Analysis quality is unaffected; this is only a presentation fallback.
- Restarting the script is usually enough to restore the image path if the session was in a bad UI state.

## I want to inspect export diagnostics without running the model

- Run `reaper/PANNs Item Report - Debug Export.lua`.
- It exports the selected take range, writes a diagnostics log, and stops before the Python runtime step.

## I am worried about temporary files

- The script only creates temporary WAVs, job files, and logs inside the REAPER app data directory.
- Those temporary artifacts are cleaned up automatically after completed runs, retries, `Another`, and window close.
- Original source audio files and project media are never deleted.

## The tags feel too generic

- The current runtime does clip-level tagging only.
- Audio is downmixed to mono and resampled to `32 kHz` before inference.
- The report is best used as a fast cueing tool, not as a precise event detector.
