from __future__ import annotations

from pathlib import Path

from reaper_audio_tag_backend import cli as cli_module
from reaper_audio_tag_backend.json_io import read_json
from reaper_audio_tag_backend.model_store import DownloadModelError, sha256_file


def test_download_model_command_writes_result_and_progress(tmp_path: Path) -> None:
    source = tmp_path / "source.onnx"
    source.write_bytes(b"model")
    digest = sha256_file(source)
    output = tmp_path / "models" / "model.onnx"
    result = tmp_path / "result.json"
    progress = tmp_path / "progress.json"
    log = tmp_path / "download.log"

    code = cli_module.main(
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

    code = cli_module.main(["verify-model", "--model-file", str(model), "--sha256", "0" * 64, "--size", "3", "--result-file", str(result)])

    assert code == 1
    payload = read_json(result)
    assert payload["status"] == "error"
    assert payload["reason"] == "checksum_mismatch"


def test_download_model_command_maps_certificate_error(tmp_path: Path) -> None:
    def fake_download_verified(**_kwargs):
        raise DownloadModelError(
            "certificate_failed",
            "Could not verify GitHub's HTTPS certificate. Update REAPER Audio Tag and try again.",
            "<urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed>",
        )

    result = tmp_path / "result.json"
    progress = tmp_path / "progress.json"
    log = tmp_path / "download.log"
    original_download_verified = cli_module.download_verified
    cli_module.download_verified = fake_download_verified
    try:
        code = cli_module.main(
            [
                "download-model",
                "--url",
                "https://github.com/example/model.onnx",
                "--output",
                str(tmp_path / "model.onnx"),
                "--sha256",
                "0" * 64,
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
    finally:
        cli_module.download_verified = original_download_verified

    payload = read_json(result)
    assert code == 1
    assert payload["error"]["code"] == "certificate_failed"
    assert payload["error"]["message"] == "Could not verify GitHub's HTTPS certificate. Update REAPER Audio Tag and try again."
    assert "CERTIFICATE_VERIFY_FAILED" in payload["error"]["detail"]


def test_download_model_command_keeps_raw_corruption_detail_out_of_user_message(tmp_path: Path) -> None:
    def fake_download_verified(**_kwargs):
        raise DownloadModelError(
            "verification_failed",
            "The download was incomplete or corrupted. Try downloading again.",
            "Downloaded model failed verification: checksum_mismatch",
        )

    result = tmp_path / "result.json"
    progress = tmp_path / "progress.json"
    log = tmp_path / "download.log"
    original_download_verified = cli_module.download_verified
    cli_module.download_verified = fake_download_verified
    try:
        code = cli_module.main(
            [
                "download-model",
                "--url",
                "https://github.com/example/model.onnx",
                "--output",
                str(tmp_path / "model.onnx"),
                "--sha256",
                "0" * 64,
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
    finally:
        cli_module.download_verified = original_download_verified

    payload = read_json(result)
    assert code == 1
    assert payload["error"]["code"] == "verification_failed"
    assert payload["error"]["message"] == "The download was incomplete or corrupted. Try downloading again."
    assert "checksum_mismatch" not in payload["error"]["message"]
    assert "checksum_mismatch" in payload["error"]["detail"]
