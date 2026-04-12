from __future__ import annotations

from tests.python.contracts import (
    ContractError,
    SCHEMA_VERSION,
    build_highlights,
    stable_predictions,
    validate_request,
    validate_response,
)


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
        "timing_ms": 123,
        "predictions": [{"label": "silence", "score": 0.98}],
        "highlights": ["silence (0.98)"],
        "warnings": [],
        "error": None,
    }
    normalized = validate_response(payload)
    assert normalized["predictions"][0]["label"] == "silence"


def test_stable_predictions_sort_by_score_then_label() -> None:
    rows = stable_predictions(
        [
            {"label": "b", "score": 0.8},
            {"label": "a", "score": 0.9},
            {"label": "c", "score": 0.8},
        ]
    )
    assert [row["label"] for row in rows] == ["a", "b", "c"]


def test_build_highlights_limits_rows() -> None:
    highlights = build_highlights(
        [
            {"label": "alpha", "score": 0.9},
            {"label": "beta", "score": 0.8},
            {"label": "gamma", "score": 0.7},
        ],
        limit=2,
    )
    assert highlights == ["alpha (0.90)", "beta (0.80)"]
