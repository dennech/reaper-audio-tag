from __future__ import annotations

import hashlib
import ssl
from pathlib import Path
from urllib.error import HTTPError, URLError

from reaper_audio_tag_backend import model_store
from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import DownloadModelError, download_verified, friendly_download_error, sha256_file, verify_file


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


def test_friendly_download_error_maps_network_timeout_and_http_failures() -> None:
    timeout = friendly_download_error(TimeoutError("timed out"))
    assert timeout.code == "network_failed"
    assert timeout.user_message == "Download failed. Check your internet connection and try again."
    assert "timed out" in timeout.detail

    offline = friendly_download_error(URLError("offline"))
    assert offline.code == "network_failed"
    assert offline.user_message == "Download failed. Check your internet connection and try again."

    http = friendly_download_error(HTTPError("https://github.com/example/model.onnx", 404, "Not Found", hdrs=None, fp=None))
    assert http.code == "http_failed"
    assert "HTTP 404" in http.user_message


def test_download_verified_deletes_partial_file_on_urlopen_error(tmp_path: Path) -> None:
    output = tmp_path / "models" / "model.onnx"
    temp_path = output.with_suffix(".onnx.download")
    temp_path.parent.mkdir(parents=True)
    temp_path.write_bytes(b"stale partial model")

    def fake_urlopen(_request, **_kwargs):
        raise URLError("offline")

    original_urlopen = model_store.urlopen
    model_store.urlopen = fake_urlopen
    raised = None
    try:
        download_verified(
            url="https://github.com/example/model.onnx",
            output=output,
            sha256="0" * 64,
            size=5,
            progress_file=None,
        )
    except DownloadModelError as exc:
        raised = exc
    finally:
        model_store.urlopen = original_urlopen

    assert raised is not None
    assert raised.code == "network_failed"
    assert not temp_path.exists()
    assert not output.exists()
