from __future__ import annotations

import json
import os
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any

SCHEMA_VERSION = "reaper-panns-item-report/v1"


class ContractError(ValueError):
    """Raised when the Lua <-> Python JSON contract is invalid."""


def _ensure_schema(payload: dict[str, Any]) -> dict[str, Any]:
    payload.setdefault("schema_version", SCHEMA_VERSION)
    return payload


def _set_private_file_permissions(path: Path) -> None:
    if os.name == "nt":
        return
    os.chmod(path, 0o600)


def read_json(path: str | Path) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ContractError("JSON payload must be an object.")
    return payload


def write_json(path: str | Path, payload: dict[str, Any]) -> Path:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile("w", encoding="utf-8", delete=False, dir=target.parent) as handle:
        json.dump(_ensure_schema(payload), handle, indent=2, ensure_ascii=False, sort_keys=True)
        handle.write("\n")
        temp_path = Path(handle.name)
    _set_private_file_permissions(temp_path)
    temp_path.replace(target)
    _set_private_file_permissions(target)
    return target


def validate_request(payload: dict[str, Any]) -> dict[str, Any]:
    schema_version = payload.get("schema_version")
    if schema_version != SCHEMA_VERSION:
        raise ContractError(
            f"Unsupported schema version: {schema_version!r}. Expected {SCHEMA_VERSION!r}."
        )

    required = ["temp_audio_path", "item_metadata", "timeout_sec"]
    missing = [key for key in required if key not in payload]
    if missing:
        raise ContractError(f"Missing request field(s): {', '.join(missing)}")

    item_metadata = payload["item_metadata"]
    if not isinstance(item_metadata, dict):
        raise ContractError("item_metadata must be an object.")

    return payload


def error_response(message: str, *, code: str, warnings: list[str] | None = None) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "status": "error",
        "error": {
            "code": code,
            "message": message,
        },
        "warnings": warnings or [],
        "predictions": [],
        "highlights": [],
    }
