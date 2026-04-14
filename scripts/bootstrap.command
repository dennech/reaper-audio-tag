#!/usr/bin/env bash
set -euo pipefail

# Internal developer/recovery helper.
# Public users should install via ReaPack and use REAPER Audio Tag: Configure.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/bootstrap_runtime.sh" "$@"
