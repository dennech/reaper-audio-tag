# @noindex
from __future__ import annotations

import os
import sys
from datetime import datetime, UTC
from pathlib import Path
from typing import Any

from .contract import SCHEMA_VERSION, read_json, write_json
from .paths import RuntimePaths


def _now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def default_config(paths: RuntimePaths, model_path: Path, preferred_backend: str, cpu_threads: int) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "created_at": _now(),
        "updated_at": _now(),
        "model": {
            "name": "Cnn14",
            "path": str(model_path),
        },
        "runtime": {
            "preferred_backend": preferred_backend,
            "cpu_threads": cpu_threads,
            "platform": sys.platform,
            "machine": os.uname().machine if hasattr(os, "uname") else "unknown",
        },
    }


def load_config(paths: RuntimePaths) -> dict[str, Any]:
    return read_json(paths.config_path)


def save_config(paths: RuntimePaths, config: dict[str, Any]) -> None:
    config["updated_at"] = _now()
    write_json(paths.config_path, config)
