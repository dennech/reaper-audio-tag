from __future__ import annotations

from pathlib import Path

from reaper_audio_tag_backend.cli import main
from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import sha256_file


def test_download_model_command_writes_result_and_progress(tmp_path: Path) -> None:
    source = tmp_path / "source.onnx"
    source.write_bytes(b"model")
    digest = sha256_file(source)
    output = tmp_path / "models" / "model.onnx"
    result = tmp_path / "result.json"
    progress = tmp_path / "progress.json"
    log = tmp_path / "download.log"

    code = main(
        [
            "download-model",
            "--url",
            source.as_uri(),
            "--output",
            str(output),
            "--sha256",
            digest,
            "--size",
            "5",
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


def test_verify_model_command_fails_safely(tmp_path: Path) -> None:
    model = tmp_path / "bad.onnx"
    model.write_bytes(b"bad")
    result = tmp_path / "verify.json"

    code = main(["verify-model", "--model-file", str(model), "--sha256", "0" * 64, "--size", "3", "--result-file", str(result)])

    assert code == 1
    payload = read_json(result)
    assert payload["status"] == "error"
    assert payload["reason"] == "checksum_mismatch"
