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
