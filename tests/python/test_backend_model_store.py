from __future__ import annotations

from pathlib import Path

from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import download_verified, sha256_file, verify_file


def test_verify_file_reports_size_and_checksum(tmp_path: Path) -> None:
    payload = tmp_path / "payload.bin"
    payload.write_bytes(b"audio tag")
    digest = sha256_file(payload)

    assert verify_file(payload, sha256=digest, size=len(b"audio tag")) == (True, "ok")
    assert verify_file(payload, sha256=digest, size=999) == (False, "size_mismatch")
    assert verify_file(payload, sha256="0" * 64, size=len(b"audio tag")) == (False, "checksum_mismatch")


def test_download_verified_supports_file_url_and_progress(tmp_path: Path) -> None:
    source = tmp_path / "source.onnx"
    source.write_bytes(b"model")
    digest = sha256_file(source)
    output = tmp_path / "models" / "model.onnx"
    progress = tmp_path / "progress.json"

    result = download_verified(
        url=source.as_uri(),
        output=output,
        sha256=digest,
        size=5,
        progress_file=progress,
    )

    assert result == output
    assert output.read_bytes() == b"model"
    assert read_json(progress)["status"] == "done"
