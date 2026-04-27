#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)"
LOCAL_EXPERIMENT_PYTHON="$REPO_ROOT/.local-models/onnx-experiment/venv/bin/python"

if [ -n "${PYTHON_BIN:-}" ]; then
  PYTHON="$PYTHON_BIN"
elif [ -x "$LOCAL_EXPERIMENT_PYTHON" ]; then
  PYTHON="$LOCAL_EXPERIMENT_PYTHON"
elif command -v python3.11 >/dev/null 2>&1; then
  PYTHON="$(command -v python3.11)"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON="$(command -v python3)"
else
  echo "Python was not found. Set PYTHON_BIN to a Python with the dev dependencies installed." >&2
  exit 1
fi

"$PYTHON" "$REPO_ROOT/tests/scripts/run_python_tests.py" --scope integration
