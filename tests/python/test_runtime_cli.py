from __future__ import annotations

import contextlib
import io
import json
import os
import stat
import tempfile
from pathlib import Path
from unittest.mock import patch

from reaper_panns_runtime.cli import main
from reaper_panns_runtime.contract import SCHEMA_VERSION, read_json, validate_response
from reaper_panns_runtime.paths import RuntimePaths, ensure_directories
from tests.python.audio_fixtures import generate_audio_fixtures


def test_bootstrap_cli_writes_config_without_real_download() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        resource_dir = Path(temp_dir) / "REAPER"
        stdout = io.StringIO()

        def fake_download(target_dir, spec, force=False):  # noqa: ANN001 - test shim
            target_dir.mkdir(parents=True, exist_ok=True)
            fake_model = target_dir / spec.filename
            fake_model.write_bytes(b"fake-model")
            return fake_model

        with patch.dict(os.environ, {"REAPER_RESOURCE_PATH": str(resource_dir)}, clear=False):
            with patch("reaper_panns_runtime.bootstrap.download_model", side_effect=fake_download):
                with contextlib.redirect_stdout(stdout):
                    exit_code = main(["bootstrap"])

        payload = json.loads(stdout.getvalue())
        assert exit_code == 0
        assert payload["status"] == "ok"
        config = read_json(resource_dir / "Data" / "reaper-panns-item-report" / "config.json")
        assert "python_executable" not in config


def test_analyze_cli_works_with_fake_model() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        resource_dir = Path(temp_dir) / "REAPER"
        data_dir = resource_dir / "Data" / "reaper-panns-item-report"
        data_dir.mkdir(parents=True, exist_ok=True)
        model_path = data_dir / "models" / "Cnn14_mAP=0.431.pth"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_bytes(b"placeholder")
        config_path = data_dir / "config.json"
        config_path.write_text(
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

        fixtures = generate_audio_fixtures(Path(temp_dir) / "fixtures")
        audio_path = Path(fixtures["fixtures"][1]["path"])
        request_path = Path(temp_dir) / "request.json"
        request_path.write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "temp_audio_path": str(audio_path),
                    "item_metadata": {"item_name": "tone_440hz"},
                    "requested_backend": "auto",
                    "timeout_sec": 15,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        stdout = io.StringIO()
        with patch.dict(
            os.environ,
            {
                "REAPER_RESOURCE_PATH": str(resource_dir),
                "REAPER_PANNS_FAKE_MODEL": "1",
            },
            clear=False,
        ):
            with contextlib.redirect_stdout(stdout):
                exit_code = main(["analyze", "--request-file", str(request_path)])

        payload = json.loads(stdout.getvalue())
        assert exit_code == 0
        assert payload["status"] == "ok"
        assert payload["backend"] == "fake"
        assert payload["predictions"]
        assert payload["summary"]
        assert payload["attempted_backends"] == ["fake"]
        assert payload["model_status"]["source"] == "managed-runtime"
        assert "path" not in payload["model_status"]
        validate_response(payload)


def test_analyze_cli_writes_log_file_when_requested() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        resource_dir = Path(temp_dir) / "REAPER"
        data_dir = resource_dir / "Data" / "reaper-panns-item-report"
        data_dir.mkdir(parents=True, exist_ok=True)
        model_path = data_dir / "models" / "Cnn14_mAP=0.431.pth"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_bytes(b"placeholder")
        config_path = data_dir / "config.json"
        config_path.write_text(
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

        fixtures = generate_audio_fixtures(Path(temp_dir) / "fixtures")
        audio_path = Path(fixtures["fixtures"][1]["path"])
        request_path = Path(temp_dir) / "request.json"
        log_path = Path(temp_dir) / "runtime.log"
        request_path.write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "temp_audio_path": str(audio_path),
                    "item_metadata": {"item_name": "tone_440hz", "item_length": 10.0},
                    "requested_backend": "auto",
                    "timeout_sec": 15,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        stdout = io.StringIO()
        with patch.dict(
            os.environ,
            {
                "REAPER_RESOURCE_PATH": str(resource_dir),
                "REAPER_PANNS_FAKE_MODEL": "1",
            },
            clear=False,
        ):
            with contextlib.redirect_stdout(stdout):
                exit_code = main(["analyze", "--request-file", str(request_path), "--log-file", str(log_path)])

        payload = json.loads(stdout.getvalue())
        assert exit_code == 0
        assert payload["status"] == "ok"
        assert log_path.exists()
        log_text = log_path.read_text(encoding="utf-8")
        assert "Analyze started." in log_text
        assert "Analyze finished successfully." in log_text


def test_analyze_cli_ignores_request_model_path_override() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        resource_dir = Path(temp_dir) / "REAPER"
        data_dir = resource_dir / "Data" / "reaper-panns-item-report"
        data_dir.mkdir(parents=True, exist_ok=True)
        model_path = data_dir / "models" / "Cnn14_mAP=0.431.pth"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_bytes(b"placeholder")
        config_path = data_dir / "config.json"
        config_path.write_text(
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

        fixtures = generate_audio_fixtures(Path(temp_dir) / "fixtures")
        audio_path = Path(fixtures["fixtures"][1]["path"])
        request_path = Path(temp_dir) / "request.json"
        request_path.write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "temp_audio_path": str(audio_path),
                    "item_metadata": {"item_name": "tone_440hz"},
                    "requested_backend": "cpu",
                    "model_path": "/tmp/evil-override.pth",
                    "timeout_sec": 15,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        observed: dict[str, str] = {}

        def fake_analyze(audio_path_arg, model_path_arg, primary_backend):  # noqa: ANN001 - test shim
            observed["audio_path"] = str(audio_path_arg)
            observed["model_path"] = str(model_path_arg)
            observed["primary_backend"] = primary_backend
            return {
                "backend": "cpu",
                "summary": "ok",
                "predictions": [],
                "highlights": [],
                "timing_ms": {"preprocess": 0, "inference": 0, "total": 0},
                "attempted_backends": ["cpu"],
                "warnings": [],
            }

        stdout = io.StringIO()
        with patch.dict(os.environ, {"REAPER_RESOURCE_PATH": str(resource_dir)}, clear=False):
            with patch("reaper_panns_runtime.cli.analyze_audio_file", side_effect=fake_analyze):
                with contextlib.redirect_stdout(stdout):
                    exit_code = main(["analyze", "--request-file", str(request_path)])

        payload = json.loads(stdout.getvalue())
        assert exit_code == 0
        assert observed["model_path"] == str(model_path)
        assert observed["primary_backend"] == "cpu"
        assert payload["status"] == "ok"
        validate_response(payload)


def test_analyze_cli_returns_normalized_error_payload() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        resource_dir = Path(temp_dir) / "REAPER"
        data_dir = resource_dir / "Data" / "reaper-panns-item-report"
        data_dir.mkdir(parents=True, exist_ok=True)
        model_path = data_dir / "models" / "Cnn14_mAP=0.431.pth"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_bytes(b"placeholder")
        config_path = data_dir / "config.json"
        config_path.write_text(
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

        fixtures = generate_audio_fixtures(Path(temp_dir) / "fixtures")
        audio_path = Path(fixtures["fixtures"][1]["path"])
        request_path = Path(temp_dir) / "request.json"
        request_path.write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "temp_audio_path": str(audio_path),
                    "item_metadata": {"item_name": "tone_440hz"},
                    "requested_backend": "auto",
                    "timeout_sec": 15,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        stdout = io.StringIO()
        with patch.dict(os.environ, {"REAPER_RESOURCE_PATH": str(resource_dir)}, clear=False):
            with patch(
                "reaper_panns_runtime.cli.analyze_audio_file",
                side_effect=RuntimeError("unexpected crash"),
            ):
                with contextlib.redirect_stdout(stdout):
                    exit_code = main(["analyze", "--request-file", str(request_path)])

        payload = json.loads(stdout.getvalue())
        assert exit_code == 1
        assert payload["status"] == "error"
        assert payload["error"]["code"] == "analysis_failed"
        assert payload["attempted_backends"] == ["mps", "cpu"]
        assert payload["summary"] == "No analysis summary is available."
        validate_response(payload)


def test_ensure_directories_normalizes_private_permissions_on_posix() -> None:
    if os.name == "nt":
        return

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        paths = RuntimePaths(
            resource_dir=root / "REAPER",
            data_dir=root / "Data" / "reaper-panns-item-report",
            runtime_dir=root / "Data" / "reaper-panns-item-report" / "runtime",
            jobs_dir=root / "Data" / "reaper-panns-item-report" / "jobs",
            logs_dir=root / "Data" / "reaper-panns-item-report" / "logs",
            tmp_dir=root / "Data" / "reaper-panns-item-report" / "tmp",
            models_dir=root / "Data" / "reaper-panns-item-report" / "models",
            config_path=root / "Data" / "reaper-panns-item-report" / "config.json",
            last_probe_path=root / "Data" / "reaper-panns-item-report" / "last_probe.json",
            venv_dir=root / "Data" / "reaper-panns-item-report" / "runtime" / "venv",
            repo_root=root,
        )

        for directory in (
            paths.data_dir,
            paths.runtime_dir,
            paths.jobs_dir,
            paths.logs_dir,
            paths.tmp_dir,
            paths.models_dir,
        ):
            directory.mkdir(parents=True, exist_ok=True)
            directory.chmod(0o755)

        ensure_directories(paths)

        for directory in (
            paths.data_dir,
            paths.runtime_dir,
            paths.jobs_dir,
            paths.logs_dir,
            paths.tmp_dir,
            paths.models_dir,
        ):
            mode = stat.S_IMODE(directory.stat().st_mode)
            assert mode == 0o700
