from __future__ import annotations

import hashlib
import ssl
from pathlib import Path

from reaper_audio_tag_backend import model_store
from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import DownloadModelError, download_verified, sha256_file, verify_file


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


def test_download_verified_uses_certifi_ssl_context_for_https(tmp_path: Path) -> None:
    captured: dict[str, object] = {}

    class FakeResponse:
        headers = {"Content-Length": "5"}

        def __init__(self) -> None:
            self._chunks = [b"model", b""]

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self, _size: int) -> bytes:
            return self._chunks.pop(0)

    def fake_urlopen(_request, **kwargs):
        captured.update(kwargs)
        return FakeResponse()

    original_urlopen = model_store.urlopen
    model_store.urlopen = fake_urlopen

    output = tmp_path / "model.onnx"
    try:
        result = download_verified(
            url="https://github.com/example/model.onnx",
            output=output,
            sha256=hashlib.sha256(b"model").hexdigest(),
            size=5,
            progress_file=None,
        )
    finally:
        model_store.urlopen = original_urlopen

    assert result == output
    assert isinstance(captured["context"], ssl.SSLContext)


def test_download_verified_reports_corrupted_download_friendly(tmp_path: Path) -> None:
    source = tmp_path / "source.onnx"
    source.write_bytes(b"model")
    output = tmp_path / "models" / "model.onnx"

    raised = None
    try:
        download_verified(
            url=source.as_uri(),
            output=output,
            sha256="0" * 64,
            size=5,
            progress_file=None,
        )
    except DownloadModelError as exc:
        raised = exc

    assert raised is not None
    assert raised.code == "verification_failed"
    assert raised.user_message == "The download was incomplete or corrupted. Try downloading again."
    assert not output.with_suffix(".onnx.download").exists()
