from __future__ import annotations

from reaper_panns_runtime.contract import ContractError, SCHEMA_VERSION, validate_request, validate_response
from reaper_panns_runtime.report import build_highlights, rank_predictions


def test_validate_request_accepts_expected_payload() -> None:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "temp_audio_path": "/tmp/item.wav",
        "item_metadata": {"item_id": "A1", "length_sec": 1.5},
        "requested_backend": "auto",
        "timeout_sec": 15,
    }
    normalized = validate_request(payload)
    assert normalized["temp_audio_path"] == "/tmp/item.wav"


def test_validate_request_rejects_bad_backend() -> None:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "temp_audio_path": "/tmp/item.wav",
        "item_metadata": {},
        "requested_backend": "gpu",
        "timeout_sec": 15,
    }
    try:
        validate_request(payload)
    except ContractError as exc:
        assert exc.code == "bad_backend"
    else:
        raise AssertionError("expected bad_backend error")


def test_validate_response_accepts_ok_result() -> None:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "status": "ok",
        "backend": "cpu",
        "attempted_backends": ["cpu"],
        "timing_ms": {"preprocess": 12, "inference": 111, "total": 123},
        "summary": "Top detected tag: silence.",
        "predictions": [
            {
                "rank": 1,
                "label": "silence",
                "score": 0.98,
                "bucket": "strong",
                "peak_score": 0.98,
                "support_count": 1,
                "segment_count": 1,
            }
        ],
        "highlights": [
            {
                "label": "silence",
                "score": 0.98,
                "bucket": "strong",
                "headline": "Likely tag",
                "peak_score": 0.98,
                "support_count": 1,
                "segment_count": 1,
            }
        ],
        "warnings": [],
        "model_status": {"name": "Cnn14", "source": "managed-runtime"},
        "item": {"item_name": "Item 1"},
        "error": None,
    }
    normalized = validate_response(payload)
    assert normalized["predictions"][0]["label"] == "silence"


def test_stable_predictions_sort_by_score_then_label() -> None:
    rows = rank_predictions(["b", "a", "c"], [0.8, 0.9, 0.8], limit=3)
    assert [row.label for row in rows] == ["a", "b", "c"]


def test_build_highlights_limits_rows() -> None:
    highlights = build_highlights(
        rank_predictions(["alpha", "beta", "gamma"], [0.9, 0.8, 0.7], limit=3),
        limit=2,
    )
    assert [row["label"] for row in highlights] == ["alpha", "beta"]
    assert highlights[0]["headline"] == "Likely tag"
