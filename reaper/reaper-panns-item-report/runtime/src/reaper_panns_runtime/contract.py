# @noindex
from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any

SCHEMA_VERSION = "reaper-panns-item-report/v1"
VALID_REQUESTED_BACKENDS = {"auto", "cpu", "mps"}
VALID_RESPONSE_STATUSES = {"ok", "error"}


@dataclass(frozen=True)
class ContractError(ValueError):
    code: str
    message: str

    def __str__(self) -> str:
        return f"{self.code}: {self.message}"


def _ensure_schema(payload: dict[str, Any]) -> dict[str, Any]:
    payload.setdefault("schema_version", SCHEMA_VERSION)
    return payload


def _set_private_file_permissions(path: Path) -> None:
    if os.name == "nt":
        return
    os.chmod(path, 0o600)


def _require(condition: bool, code: str, message: str) -> None:
    if not condition:
        raise ContractError(code=code, message=message)


def _is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def zero_timing_ms() -> dict[str, int]:
    return {"preprocess": 0, "inference": 0, "total": 0}


def read_json(path: str | Path) -> dict[str, Any]:
    target = Path(path)
    try:
        with target.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except FileNotFoundError as exc:
        raise ContractError("missing_json", f"JSON file was not found: {target}") from exc
    except json.JSONDecodeError as exc:
        raise ContractError("bad_json", f"JSON file is malformed: {target}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ContractError("bad_json_type", "JSON payload must be an object.")
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
    _require(isinstance(payload, dict), "bad_request_type", "request payload must be an object")
    _require(
        payload.get("schema_version") == SCHEMA_VERSION,
        "schema_mismatch",
        f"Unsupported schema version: {payload.get('schema_version')!r}. Expected {SCHEMA_VERSION!r}.",
    )
    _require(
        _is_non_empty_string(payload.get("temp_audio_path")),
        "missing_audio_path",
        "temp_audio_path must be a non-empty string.",
    )
    _require(
        isinstance(payload.get("item_metadata"), dict),
        "bad_item_metadata",
        "item_metadata must be an object.",
    )
    _require(
        payload.get("requested_backend") in VALID_REQUESTED_BACKENDS,
        "bad_backend",
        "requested_backend must be one of: auto, cpu, mps.",
    )
    timeout_sec = payload.get("timeout_sec")
    _require(
        isinstance(timeout_sec, (int, float)) and float(timeout_sec) > 0,
        "bad_timeout",
        "timeout_sec must be a positive number.",
    )
    return dict(payload)


def _validate_timing_ms(payload: dict[str, Any]) -> dict[str, int]:
    timing_ms = payload.get("timing_ms")
    _require(isinstance(timing_ms, dict), "bad_timing", "timing_ms must be an object.")
    normalized: dict[str, int] = {}
    for key in ("preprocess", "inference", "total"):
        value = timing_ms.get(key)
        _require(
            isinstance(value, (int, float)) and float(value) >= 0,
            "bad_timing",
            f"timing_ms.{key} must be a non-negative number.",
        )
        normalized[key] = int(round(float(value)))
    return normalized


def _validate_prediction_rows(rows: Any, *, field_name: str, require_headline: bool) -> None:
    _require(isinstance(rows, list), f"bad_{field_name}", f"{field_name} must be a list.")
    for row in rows:
        _require(isinstance(row, dict), f"bad_{field_name}_row", f"{field_name} rows must be objects.")
        _require(_is_non_empty_string(row.get("label")), f"bad_{field_name}_label", f"{field_name}.label must be a string.")
        score = row.get("score")
        _require(
            isinstance(score, (int, float)) and 0.0 <= float(score) <= 1.0,
            f"bad_{field_name}_score",
            f"{field_name}.score must be between 0 and 1.",
        )
        bucket = row.get("bucket")
        _require(_is_non_empty_string(bucket), f"bad_{field_name}_bucket", f"{field_name}.bucket must be a string.")
        if field_name == "predictions":
            rank = row.get("rank")
            _require(isinstance(rank, int) and rank >= 1, "bad_prediction_rank", "predictions.rank must be >= 1.")
        for optional_float in ("peak_score",):
            if optional_float in row:
                _require(
                    isinstance(row[optional_float], (int, float)) and 0.0 <= float(row[optional_float]) <= 1.0,
                    f"bad_{field_name}_{optional_float}",
                    f"{field_name}.{optional_float} must be between 0 and 1.",
                )
        for optional_int in ("support_count", "segment_count"):
            if optional_int in row:
                _require(
                    isinstance(row[optional_int], int) and row[optional_int] >= 0,
                    f"bad_{field_name}_{optional_int}",
                    f"{field_name}.{optional_int} must be a non-negative integer.",
                )
        if require_headline:
            _require(
                _is_non_empty_string(row.get("headline")),
                "bad_highlight_headline",
                "highlights.headline must be a string.",
            )


def validate_response(payload: dict[str, Any]) -> dict[str, Any]:
    _require(isinstance(payload, dict), "bad_response_type", "response payload must be an object")
    _require(
        payload.get("schema_version") == SCHEMA_VERSION,
        "schema_mismatch",
        f"Unsupported schema version: {payload.get('schema_version')!r}. Expected {SCHEMA_VERSION!r}.",
    )
    _require(payload.get("status") in VALID_RESPONSE_STATUSES, "bad_status", "status must be 'ok' or 'error'.")
    _require(_is_non_empty_string(payload.get("backend")), "bad_backend", "backend must be a string.")
    attempted_backends = payload.get("attempted_backends")
    _require(isinstance(attempted_backends, list), "bad_attempted_backends", "attempted_backends must be a list.")
    for backend in attempted_backends:
        _require(_is_non_empty_string(backend), "bad_attempted_backend", "attempted_backends must contain strings.")
    _require(isinstance(payload.get("summary"), str), "bad_summary", "summary must be a string.")
    _validate_timing_ms(payload)
    _validate_prediction_rows(payload.get("predictions"), field_name="predictions", require_headline=False)
    _validate_prediction_rows(payload.get("highlights"), field_name="highlights", require_headline=True)

    warnings = payload.get("warnings")
    _require(isinstance(warnings, list), "bad_warnings", "warnings must be a list.")
    for warning in warnings:
        _require(_is_non_empty_string(warning), "bad_warning", "warnings must contain strings.")

    model_status = payload.get("model_status")
    _require(isinstance(model_status, dict), "bad_model_status", "model_status must be an object.")

    item = payload.get("item")
    _require(isinstance(item, dict), "bad_item", "item must be an object.")

    error = payload.get("error")
    if error is not None:
        _require(isinstance(error, dict), "bad_error", "error must be null or an object.")
        _require(_is_non_empty_string(error.get("code")), "bad_error_code", "error.code must be a string.")
        _require(_is_non_empty_string(error.get("message")), "bad_error_message", "error.message must be a string.")

    return dict(payload)


def response_payload(
    *,
    schema_version: str = SCHEMA_VERSION,
    status: str,
    backend: str,
    attempted_backends: list[str] | None = None,
    timing_ms: dict[str, int] | None = None,
    summary: str = "",
    predictions: list[dict[str, Any]] | None = None,
    highlights: list[dict[str, Any]] | None = None,
    warnings: list[str] | None = None,
    model_status: dict[str, Any] | None = None,
    item: dict[str, Any] | None = None,
    error: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": schema_version,
        "status": status,
        "backend": backend,
        "attempted_backends": attempted_backends or [],
        "timing_ms": dict(timing_ms or zero_timing_ms()),
        "summary": summary,
        "predictions": list(predictions or []),
        "highlights": list(highlights or []),
        "warnings": list(warnings or []),
        "model_status": dict(model_status or {}),
        "item": dict(item or {}),
        "error": error,
    }


def error_response(
    message: str,
    *,
    code: str,
    schema_version: str = SCHEMA_VERSION,
    backend: str = "cpu",
    attempted_backends: list[str] | None = None,
    timing_ms: dict[str, int] | None = None,
    warnings: list[str] | None = None,
    model_status: dict[str, Any] | None = None,
    item: dict[str, Any] | None = None,
    summary: str = "No analysis summary is available.",
) -> dict[str, Any]:
    return response_payload(
        schema_version=schema_version,
        status="error",
        backend=backend,
        attempted_backends=attempted_backends,
        timing_ms=timing_ms,
        summary=summary,
        predictions=[],
        highlights=[],
        warnings=warnings,
        model_status=model_status,
        item=item,
        error={
            "code": code,
            "message": message,
        },
    )
