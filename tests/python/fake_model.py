from __future__ import annotations

from pathlib import Path
from typing import Any

from tests.python.audio_fixtures import describe_audio
from tests.python.contracts import build_highlights, error_payload, stable_predictions


def _backend_from_request(requested_backend: str, allow_mps: bool) -> tuple[str, list[str]]:
    warnings: list[str] = []
    if requested_backend == "mps":
        if allow_mps:
            return "mps", warnings
        warnings.append("mps_requested_but_unavailable")
        return "cpu", warnings
    if requested_backend == "auto":
        if allow_mps:
            return "mps", warnings
        return "cpu", warnings
    return "cpu", warnings


def _score(label: str, base: float, modifier: float = 0.0) -> dict[str, Any]:
    score = max(0.0, min(0.99, base + modifier))
    return {"label": label, "score": round(score, 4)}


def _predictions_from_stats(stats: dict[str, Any]) -> list[dict[str, Any]]:
    rms = float(stats["rms"])
    peak = float(stats["peak"])
    zero_crossings = int(stats["zero_crossings"])
    duration = float(stats["duration_sec"])
    peak_rms_ratio = peak / max(rms, 0.001)

    rows: list[dict[str, Any]] = []
    if rms < 0.01:
        rows.extend(
            [
                _score("silence", 0.98),
                _score("room tone", 0.72),
                _score("low energy", 0.66),
            ]
        )
    elif zero_crossings < 80 and peak > 0.7:
        rows.extend(
            [
                _score("transient", 0.93),
                _score("clicks", 0.84),
                _score("percussive", 0.73),
            ]
        )
    elif 900 <= zero_crossings <= 1700 and peak_rms_ratio < 1.8:
        rows.extend(
            [
                _score("sine tone", 0.94),
                _score("steady signal", 0.89),
                _score("tonal sound", 0.82),
            ]
        )
    elif zero_crossings > 5000 and rms > 0.12:
        rows.extend(
            [
                _score("broadband noise", 0.95),
                _score("hiss", 0.78),
                _score("texture", 0.70),
            ]
        )
    else:
        rows.extend(
            [
                _score("mixed content", 0.91),
                _score("steady tone", 0.79),
                _score("noise bed", 0.68),
            ]
        )

    rows.append(_score("longer clip" if duration > 1.0 else "short clip", 0.42))
    return stable_predictions(rows, limit=5)


def analyze_audio_request(request: dict[str, Any], *, allow_mps: bool = False) -> dict[str, Any]:
    temp_audio_path = Path(request["temp_audio_path"])
    backend, warnings = _backend_from_request(str(request.get("requested_backend", "auto")), allow_mps=allow_mps)
    stats = describe_audio(temp_audio_path)
    predictions = _predictions_from_stats(stats)
    timing_ms = int(round(120.0 + stats["duration_sec"] * 210.0 + (45.0 if backend == "mps" else 110.0)))

    response = {
        "schema_version": request["schema_version"],
        "status": "ok",
        "backend": backend,
        "timing_ms": timing_ms,
        "predictions": predictions,
        "highlights": build_highlights(predictions, limit=4),
        "warnings": warnings,
        "error": None,
        "stats": stats,
    }
    return response


def error_response(code: str, message: str, backend: str = "cpu") -> dict[str, Any]:
    return {
        "schema_version": "1",
        "status": "error",
        "backend": backend,
        "timing_ms": 0,
        "predictions": [],
        "highlights": [],
        "warnings": [],
        "error": error_payload(code, message),
    }
