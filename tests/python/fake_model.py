from __future__ import annotations

from pathlib import Path
from typing import Any

from reaper_panns_runtime.backend import backend_candidates
from reaper_panns_runtime.contract import error_response as contract_error_response
from reaper_panns_runtime.contract import response_payload, zero_timing_ms
from reaper_panns_runtime.report import build_highlights, build_summary, rank_predictions
from tests.python.audio_fixtures import describe_audio


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
    labels = [row["label"] for row in rows]
    scores = [row["score"] for row in rows]
    return [prediction.to_dict() for prediction in rank_predictions(labels, scores, limit=5)]


def analyze_audio_request(request: dict[str, Any], *, allow_mps: bool = False) -> dict[str, Any]:
    temp_audio_path = Path(request["temp_audio_path"])
    requested_backend = str(request.get("requested_backend", "auto"))
    attempted_backends = backend_candidates(requested_backend)
    warnings: list[str] = []
    if "mps" in attempted_backends and not allow_mps:
        warnings.append("mps probe failed: fake test backend is unavailable.")
        backend = "cpu"
    else:
        backend = "mps" if "mps" in attempted_backends and allow_mps else "cpu"
    stats = describe_audio(temp_audio_path)
    predictions = _predictions_from_stats(stats)
    ranked_predictions = rank_predictions(
        [row["label"] for row in predictions],
        [row["score"] for row in predictions],
        limit=5,
    )
    timing_total = int(round(120.0 + stats["duration_sec"] * 210.0 + (45.0 if backend == "mps" else 110.0)))
    timing_ms = zero_timing_ms()
    timing_ms["total"] = timing_total
    timing_ms["inference"] = timing_total

    return response_payload(
        schema_version=request["schema_version"],
        status="ok",
        backend=backend,
        attempted_backends=attempted_backends,
        timing_ms=timing_ms,
        summary=build_summary(ranked_predictions),
        predictions=[prediction.to_dict() for prediction in ranked_predictions],
        highlights=build_highlights(ranked_predictions, limit=4),
        warnings=warnings,
        model_status={"name": "Fake Cnn14", "source": "test-fixture"},
        item=dict(request.get("item_metadata", {})),
        error=None,
    )


def error_response(code: str, message: str, backend: str = "cpu") -> dict[str, Any]:
    return contract_error_response(message, code=code, backend=backend)
