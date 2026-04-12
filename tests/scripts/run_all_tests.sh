#!/bin/sh
set -eu
python3 tests/scripts/run_python_tests.py --scope all
lua tests/lua/run_tests.lua

