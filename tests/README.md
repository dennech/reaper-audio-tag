# Test Layer

This directory contains the repository test scaffold for `REAPER PANNs Item Report v1`.

## Layout

- `tests/python`: Python tests for fixtures, contracts, and the real `reaper_panns_runtime` fake-path.
- `tests/lua`: pure Lua report presenter tests plus snapshot checks.
- `tests/integration`: cross-language checks that connect the runtime CLI fake mode with the Lua report layer.
- `tests/scripts`: local runners and deterministic fixture generation.
- `tests/lua/snapshots`: text snapshots used by the Lua formatter tests.

## Local commands

- `python3 tests/scripts/run_python_tests.py --scope python`
- `python3 tests/scripts/run_python_tests.py --scope integration`
- `lua tests/lua/run_tests.lua`
- `python3 tests/scripts/generate_audio_fixtures.py --output-dir /tmp/panns-fixtures`

The Python runner uses `pytest` when available and falls back to a tiny built-in discovery runner when it is not.

## Manual REAPER smoke checklist

- Normal audio item with no trimming.
- Cropped item cut from the left side of a longer source file.
- Cropped item cut from the right side of a longer source file.
- Item placed at a non-zero project position.
- Item with `playrate != 1.0`.
- Looped source item.
- Very short clip.
- Live reproducer shape like `23-1.wav`: `accessor_start=0`, `accessor_end=item_length`, `take_start_offset=item_position`, `loop_source=true`.

Acceptance for all manual cases:

- The report should follow the selected item range, not the whole source file.
- Export should not fail only because `accessor_start/accessor_end` disagree with the selected range.
- When export cannot read part of the range, analysis should still run with padded silence and mark the range as clamped.
- Only a fully unreadable range should surface `export_failed`.
- `reaper/PANNs Item Report - Debug Export.lua` should write a diagnostics log without starting the model runtime.
- After a finished run, selecting a different item and clicking `Another` should start a new analysis without closing the window.
- Completed runs should not leave a fresh export WAV behind in `Data/reaper-panns-item-report/tmp`.
- Cleanup must touch only plugin-owned artifacts under `tmp`, `jobs`, and `logs`; original source media must remain untouched.
