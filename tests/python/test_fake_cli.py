from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from reaper_panns_runtime.contract import SCHEMA_VERSION, validate_response
from tests.python.audio_fixtures import generate_audio_fixtures


def _run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-m", "tests.python.fake_panns_cli", *args],
        check=False,
        text=True,
        capture_output=True,
        env={
            **os.environ,
            "PYTHONPATH": str(Path.cwd() / "reaper" / "runtime" / "src"),
        },
    )


def test_bootstrap_command_returns_json() -> None:
    completed = _run_cli("bootstrap")
    assert completed.returncode == 0
    payload = json.loads(completed.stdout)
    assert payload["status"] == "ok"
    assert payload["schema_version"] == SCHEMA_VERSION


def test_probe_command_accepts_request_shape() -> None:
    completed = _run_cli("probe", "--temp-audio-path", "/tmp/item.wav", "--requested-backend", "auto")
    assert completed.returncode == 0
    payload = json.loads(completed.stdout)
    assert payload["backend"] in {"cpu", "mps"}
    assert payload["available_backends"][0] == "cpu"


def test_analyze_command_generates_stable_response() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        fixtures = generate_audio_fixtures(root / "fixtures")
        item = next(fixture for fixture in fixtures["fixtures"] if fixture["name"] == "tone_440hz")
        request_path = root / "request.json"
        request_path.write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "temp_audio_path": item["path"],
                    "item_metadata": {"item_id": "item-1", "name": "tone"},
                    "requested_backend": "auto",
                    "timeout_sec": 10,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        completed = _run_cli("analyze", "--request-file", str(request_path))
        assert completed.returncode == 0
        payload = json.loads(completed.stdout)
        assert payload["status"] == "ok"
        assert payload["predictions"][0]["label"] == "sine tone"
        assert payload["highlights"][0]["label"] == "sine tone"
        assert payload["attempted_backends"] == ["mps", "cpu"]
        validate_response(payload)
