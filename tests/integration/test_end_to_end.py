from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from tests.python.audio_fixtures import generate_audio_fixtures
from reaper_panns_runtime.contract import SCHEMA_VERSION


def test_runtime_cli_fake_mode_and_lua_runner_work_together() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        resource_dir = root / "REAPER"
        data_dir = resource_dir / "Data" / "reaper-panns-item-report"
        data_dir.mkdir(parents=True, exist_ok=True)
        model_path = data_dir / "models" / "Cnn14_mAP=0.431.pth"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_bytes(b"placeholder")
        (data_dir / "config.json").write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "model": {"name": "Cnn14", "path": str(model_path)},
                    "runtime": {"preferred_backend": "cpu", "cpu_threads": 2},
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        fixtures = generate_audio_fixtures(root / "fixtures")
        item = next(fixture for fixture in fixtures["fixtures"] if fixture["name"] == "mix_tone_noise")
        request = {
            "schema_version": SCHEMA_VERSION,
            "temp_audio_path": item["path"],
            "item_metadata": {
                "item_id": "item-42",
                "take_name": "Mix Take",
                "selected": True,
            },
            "requested_backend": "mps",
            "timeout_sec": 12,
        }
        request_path = root / "request.json"
        request_path.write_text(json.dumps(request, indent=2) + "\n", encoding="utf-8")

        cli = subprocess.run(
            [sys.executable, "-m", "reaper_panns_runtime.cli", "analyze", "--request-file", str(request_path)],
            check=False,
            text=True,
            capture_output=True,
            env={
                **os.environ,
                "PYTHONPATH": str(Path.cwd() / "runtime" / "src"),
                "REAPER_RESOURCE_PATH": str(resource_dir),
                "REAPER_PANNS_FAKE_MODEL": "1",
            },
        )
        assert cli.returncode == 0
        response = json.loads(cli.stdout)
        assert response["backend"] == "fake"
        assert response["status"] == "ok"

        lua = subprocess.run(
            ["lua", "tests/lua/run_tests.lua"],
            check=False,
            text=True,
            capture_output=True,
        )
        assert lua.returncode == 0, lua.stdout + lua.stderr
