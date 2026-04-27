from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from reaper_audio_tag_backend.cli import main
from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import sha256_file


def test_backend_download_contract_and_lua_suite_work_together(tmp_path: Path) -> None:
    source = tmp_path / "source.onnx"
    source.write_bytes(b"onnx fixture")
    digest = sha256_file(source)
    model = tmp_path / "Data" / "reaper-panns-item-report" / "models" / "cnn14_waveform_clipwise_opset17.onnx"
    progress = tmp_path / "progress.json"
    result = tmp_path / "download-result.json"
    log = tmp_path / "download.log"

    code = main(
        [
            "download-model",
            "--url",
            source.as_uri(),
            "--output",
            str(model),
            "--sha256",
            digest,
            "--size",
            str(source.stat().st_size),
            "--progress-file",
            str(progress),
            "--result-file",
            str(result),
            "--log-file",
            str(log),
        ]
    )

    assert code == 0
    assert read_json(result)["status"] == "ok"
    assert read_json(progress)["status"] == "done"
    assert model.read_bytes() == source.read_bytes()

    lua = subprocess.run(
        ["lua", "tests/lua/run_tests.lua"],
        check=False,
        text=True,
        capture_output=True,
    )
    assert lua.returncode == 0, lua.stdout + lua.stderr


def test_backend_cli_self_test_writes_json(tmp_path: Path) -> None:
    result = tmp_path / "self-test.json"
    completed = subprocess.run(
        [sys.executable, "-m", "reaper_audio_tag_backend", "self-test", "--result-file", str(result)],
        check=False,
        text=True,
        capture_output=True,
        env={**os.environ, "PYTHONPATH": str(Path.cwd() / "backend")},
    )

    assert completed.returncode == 0, completed.stdout + completed.stderr
    payload = json.loads(result.read_text(encoding="utf-8"))
    assert payload["status"] == "ok"
    assert isinstance(payload["providers"], list)
