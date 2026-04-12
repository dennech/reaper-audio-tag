from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable


SCHEMA_VERSION = "1"


VALID_BACKENDS = {"auto", "cpu", "mps"}
VALID_STATUSES = {"ok", "warning", "error", "pending"}


@dataclass(frozen=True)
class ContractError(Exception):
    code: str
    message: str

    def __str__(self) -> str:
        return f"{self.code}: {self.message}"


def _require(condition: bool, code: str, message: str) -> None:
    if not condition:
        raise ContractError(code=code, message=message)


def _is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_request(payload: dict[str, Any]) -> dict[str, Any]:
    _require(isinstance(payload, dict), "bad_request_type", "request must be an object")
    _require(payload.get("schema_version") == SCHEMA_VERSION, "schema_mismatch", "unsupported request schema_version")
    _require(_is_non_empty_string(payload.get("temp_audio_path")), "missing_audio_path", "temp_audio_path is required")
    _require(isinstance(payload.get("item_metadata"), dict), "bad_item_metadata", "item_metadata must be an object")
    _require(payload.get("requested_backend") in VALID_BACKENDS, "bad_backend", "requested_backend must be auto, cpu, or mps")
    timeout = payload.get("timeout_sec")
    _require(isinstance(timeout, (int, float)) and timeout > 0, "bad_timeout", "timeout_sec must be a positive number")

    normalized = dict(payload)
    normalized.setdefault("item_metadata", {})
    return normalized


def _validate_prediction(prediction: dict[str, Any]) -> None:
    _require(isinstance(prediction, dict), "bad_prediction", "prediction rows must be objects")
    _require(_is_non_empty_string(prediction.get("label")), "bad_prediction_label", "prediction.label must be a string")
    score = prediction.get("score")
    _require(isinstance(score, (int, float)), "bad_prediction_score", "prediction.score must be numeric")
    _require(0.0 <= float(score) <= 1.0, "bad_prediction_score", "prediction.score must be between 0 and 1")


def validate_response(payload: dict[str, Any]) -> dict[str, Any]:
    _require(isinstance(payload, dict), "bad_response_type", "response must be an object")
    _require(payload.get("schema_version") == SCHEMA_VERSION, "schema_mismatch", "unsupported response schema_version")
    _require(payload.get("status") in VALID_STATUSES, "bad_status", "status must be ok, warning, error, or pending")
    _require(_is_non_empty_string(payload.get("backend")), "bad_backend", "backend must be a string")

    timing = payload.get("timing_ms")
    _require(isinstance(timing, (int, float)) and timing >= 0, "bad_timing", "timing_ms must be a non-negative number")

    predictions = payload.get("predictions", [])
    _require(isinstance(predictions, list), "bad_predictions", "predictions must be a list")
    for prediction in predictions:
        _validate_prediction(prediction)

    highlights = payload.get("highlights", [])
    _require(isinstance(highlights, list), "bad_highlights", "highlights must be a list")
    for item in highlights:
        _require(_is_non_empty_string(item), "bad_highlight", "highlights must contain strings")

    warnings = payload.get("warnings", [])
    _require(isinstance(warnings, list), "bad_warnings", "warnings must be a list")
    for item in warnings:
        _require(_is_non_empty_string(item), "bad_warning", "warnings must contain strings")

    error = payload.get("error")
    if error is not None:
        _require(isinstance(error, dict), "bad_error", "error must be null or an object")
        _require(_is_non_empty_string(error.get("code")), "bad_error_code", "error.code must be a string")
        _require(_is_non_empty_string(error.get("message")), "bad_error_message", "error.message must be a string")

    return dict(payload)


def stable_predictions(predictions: Iterable[dict[str, Any]], limit: int | None = None) -> list[dict[str, Any]]:
    rows = [dict(row) for row in predictions]
    rows.sort(key=lambda row: (-float(row.get("score", 0.0)), str(row.get("label", "")).lower()))
    if limit is not None:
        rows = rows[:limit]
    return rows


def build_highlights(predictions: Iterable[dict[str, Any]], limit: int = 4) -> list[str]:
    rows = stable_predictions(predictions, limit=limit)
    return [f"{row['label']} ({row['score']:.2f})" for row in rows]


def error_payload(code: str, message: str) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
    }
