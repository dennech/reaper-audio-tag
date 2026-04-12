#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${1:-}" == "--dev" ]]; then
  INSTALL_DEV="1"
  shift
else
  INSTALL_DEV="0"
fi

PYTHON_BIN="${PYTHON_BIN:-$(command -v python3.11 || true)}"
if [[ -z "${PYTHON_BIN}" ]]; then
  echo "python3.11 was not found in PATH. Install Python 3.11 and run this script again." >&2
  exit 1
fi

REAPER_RESOURCE_PATH="${REAPER_RESOURCE_PATH:-${HOME}/Library/Application Support/REAPER}"
APP_DIR="${REAPER_RESOURCE_PATH}/Data/reaper-panns-item-report"
VENV_DIR="${APP_DIR}/runtime/venv"

mkdir -p "${APP_DIR}/runtime"
"${PYTHON_BIN}" -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel
if [[ "${INSTALL_DEV}" == "1" ]]; then
  "${VENV_DIR}/bin/python" -m pip install -e "${REPO_ROOT}[dev]"
else
  "${VENV_DIR}/bin/python" -m pip install --upgrade "${REPO_ROOT}"
fi

export REAPER_RESOURCE_PATH
export REAPER_PANNS_REPO_ROOT="${REPO_ROOT}"
"${VENV_DIR}/bin/reaper-panns-runtime" bootstrap "$@"

echo
echo "Bootstrap complete."
echo "REAPER config: ${APP_DIR}/config.json"
echo "Add reaper/PANNs Item Report.lua to REAPER Actions and run it on a selected audio item."
