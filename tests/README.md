# Test Layer

This directory contains the repository test scaffold for `REAPER Audio Tag`.

## Layout

- `tests/python`: backend unit tests for WAV loading, model download/verification, report ranking, and CLI contracts.
- `tests/lua`: pure Lua UI/report/runtime-launch tests plus snapshot checks.
- `tests/integration`: smoke checks that connect the backend CLI and Lua test layer.
- `tests/scripts`: local runners and deterministic fixture generation.
- `tests/lua/snapshots`: text snapshots used by Lua formatter tests.

## Local Commands

- `python3 tests/scripts/run_python_tests.py --scope python`
- `python3 tests/scripts/run_python_tests.py --scope integration`
- `lua tests/lua/run_tests.lua`
- `python3 tests/scripts/generate_audio_fixtures.py --output-dir /tmp/panns-fixtures`

The Python runner uses `pytest` when available and falls back to a tiny built-in discovery runner when it is not.

## Manual REAPER Smoke Checklist

Install-layout expectation for public ReaPack releases:

- Lua files install under `~/Library/Application Support/REAPER/Scripts/REAPER Audio Tag/reaper/...`
- backend assets install under `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/bin/...`
- labels install under `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/metadata/...`
- the first-run ONNX model downloads to `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models/...`

Manual cases:

- Fresh install opens the model download screen, not Configure or Setup.
- `Download Model` shows progress and verifies checksum.
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
- `reaper/REAPER Audio Tag - Debug Export.lua` should write a diagnostics log without starting the backend.
- After a finished run, selecting a different item and clicking `Another` should start a new analysis without closing the window.
- Completed runs should not leave a fresh export WAV behind in `Data/reaper-panns-item-report/tmp`.
- Cleanup must touch only plugin-owned artifacts under `tmp`, `jobs`, and `logs`; original source media must remain untouched.
- Compact chips and section/status rows should render bundled Noto Emoji images rather than custom sticker art or text-emoji glyphs.
- If one emoji image handle becomes invalid, the affected UI row should degrade to plain text instead of crashing the script.
