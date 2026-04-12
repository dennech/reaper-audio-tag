from __future__ import annotations

from reaper_panns_runtime.contract import ContractError, SCHEMA_VERSION, validate_request


def test_validate_request_accepts_expected_shape() -> None:
    payload = validate_request(
        {
            "schema_version": SCHEMA_VERSION,
            "temp_audio_path": "/tmp/item.wav",
            "item_metadata": {"item_name": "Item 1"},
            "requested_backend": "auto",
            "timeout_sec": 30,
        }
    )
    assert payload["schema_version"] == SCHEMA_VERSION
    assert payload["item_metadata"]["item_name"] == "Item 1"


def test_validate_request_rejects_missing_required_fields() -> None:
    try:
        validate_request(
            {
                "schema_version": SCHEMA_VERSION,
                "item_metadata": {},
                "timeout_sec": 30,
            }
        )
    except ContractError:
        return
    raise AssertionError("validate_request should reject missing required fields")
