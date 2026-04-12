from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback
from pathlib import Path
from typing import Any

from .backend import backend_candidates, probe_backend
from .bootstrap import bootstrap_runtime
from .config_store import load_config
from .contract import (
    ContractError,
    error_response,
    read_json,
    response_payload,
    validate_request,
    validate_response,
    write_json,
    zero_timing_ms,
)
from .fake_model import analyze_with_fake_model
from .model_adapter import InferenceError, analyze_audio_file
from .paths import default_paths


def _dump(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, indent=2, ensure_ascii=False, sort_keys=True)
    sys.stdout.write("\n")


def _configured_model_path(config: dict[str, Any]) -> Path:
    return Path(config["model"]["path"])


def _log_line(log_file: Path | None, message: str) -> None:
    if log_file is None:
        return
    log_file.parent.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with log_file.open("a", encoding="utf-8") as handle:
        handle.write(f"[{timestamp}] {message}\n")
    if os.name != "nt":
        os.chmod(log_file, 0o600)


def _analyze(args: argparse.Namespace) -> int:
    log_file = Path(args.log_file) if args.log_file else None
    _log_line(log_file, f"Analyze started. request_file={args.request_file}")
    try:
        request = validate_request(read_json(args.request_file))
    except ContractError as exc:
        _log_line(log_file, f"Request validation failed: {exc.code}: {exc.message}")
        payload = error_response(
            exc.message,
            code=exc.code,
        )
        if args.result_file:
            write_json(args.result_file, payload)
        else:
            _dump(payload)
        return 1

    paths = default_paths()
    requested_backend = request.get("requested_backend") or "auto"
    default_model_status = {"name": "Cnn14", "source": "managed-runtime"}
    _log_line(log_file, f"Validated request. requested_backend={requested_backend}")

    try:
        config = load_config(paths)
    except FileNotFoundError:
        _log_line(log_file, "Runtime config is missing. bootstrap.command must be run first.")
        payload = error_response(
            "Runtime is not configured yet. Run scripts/bootstrap.command first.",
            code="runtime_not_bootstrapped",
            backend="cpu",
            attempted_backends=backend_candidates(requested_backend),
            model_status=default_model_status,
            item=request["item_metadata"],
        )
        if args.result_file:
            write_json(args.result_file, payload)
        else:
            _dump(payload)
        return 2

    audio_path = Path(request["temp_audio_path"])
    model_path = _configured_model_path(config)
    requested_backend = request.get("requested_backend") or config["runtime"]["preferred_backend"]
    model_status = {
        "name": config["model"]["name"],
        "source": "managed-runtime",
    }
    _log_line(
        log_file,
        (
            f"Resolved managed runtime. backend_strategy={requested_backend} "
            f"audio={audio_path.name} item_length={request['item_metadata'].get('item_length', 'n/a')}"
        ),
    )

    try:
        if args.fake_model or os.environ.get("REAPER_PANNS_FAKE_MODEL") == "1":
            _log_line(log_file, "Using fake model.")
            result = analyze_with_fake_model(audio_path)
            backend = "fake"
            warnings = []
            timing = zero_timing_ms()
            attempted_backends = ["fake"]
        else:
            _log_line(log_file, "Running real model inference.")
            runtime_result = analyze_audio_file(audio_path, model_path, primary_backend=requested_backend)
            result = runtime_result
            backend = runtime_result["backend"]
            warnings = runtime_result["warnings"]
            timing = runtime_result["timing_ms"]
            attempted_backends = runtime_result["attempted_backends"]

        payload = response_payload(
            schema_version=request["schema_version"],
            status="ok",
            backend=backend,
            attempted_backends=attempted_backends,
            timing_ms=timing,
            summary=result["summary"],
            predictions=result["predictions"],
            highlights=result["highlights"],
            warnings=warnings,
            model_status=model_status,
            item=request["item_metadata"],
            error=None,
        )
        _log_line(
            log_file,
            (
                f"Analyze finished successfully. backend={backend} "
                f"attempted={attempted_backends} total_ms={timing['total']}"
            ),
        )
    except InferenceError as exc:
        _log_line(
            log_file,
            f"Inference failed after backend attempts {exc.attempted_backends}: {exc}. warnings={exc.warnings}",
        )
        payload = error_response(
            str(exc),
            code="backend_attempts_failed",
            backend=exc.attempted_backends[-1] if exc.attempted_backends else "cpu",
            attempted_backends=exc.attempted_backends,
            warnings=exc.warnings,
            model_status=model_status,
            item=request["item_metadata"],
        )
    except Exception as exc:
        _log_line(log_file, f"Unexpected analysis failure: {exc}")
        _log_line(log_file, traceback.format_exc().rstrip())
        payload = error_response(
            str(exc),
            code="analysis_failed",
            backend="cpu",
            attempted_backends=backend_candidates(requested_backend),
            model_status=model_status,
            item=request["item_metadata"],
        )

    validate_response(payload)

    if args.result_file:
        write_json(args.result_file, payload)
        _log_line(log_file, f"Wrote result file: {args.result_file}")
    else:
        _dump(payload)
    return 0 if payload["status"] == "ok" else 1


def _bootstrap(args: argparse.Namespace) -> int:
    payload = bootstrap_runtime(default_paths(), preferred_backend=args.preferred_backend, force_download=args.force_download)
    if args.output:
        write_json(args.output, payload)
    else:
        _dump(payload)
    return 0


def _probe(args: argparse.Namespace) -> int:
    probe = probe_backend(args.requested_backend)
    payload = {"status": probe.status, "probe": probe.to_dict()}
    if args.output:
        write_json(args.output, payload)
    else:
        _dump(payload)
    return 0 if probe.status == "ok" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="reaper-panns-runtime")
    subparsers = parser.add_subparsers(dest="command", required=True)

    bootstrap_parser = subparsers.add_parser("bootstrap", help="Prepare runtime directories, model, and config.")
    bootstrap_parser.add_argument("--preferred-backend", default="auto", choices=["auto", "mps", "cpu"])
    bootstrap_parser.add_argument("--force-download", action="store_true")
    bootstrap_parser.add_argument("--output")
    bootstrap_parser.set_defaults(func=_bootstrap)

    probe_parser = subparsers.add_parser("probe", help="Probe available acceleration backends.")
    probe_parser.add_argument("--requested-backend", default="auto", choices=["auto", "mps", "cpu"])
    probe_parser.add_argument("--output")
    probe_parser.set_defaults(func=_probe)

    analyze_parser = subparsers.add_parser("analyze", help="Analyze a prepared WAV request file.")
    analyze_parser.add_argument("--request-file", required=True)
    analyze_parser.add_argument("--result-file")
    analyze_parser.add_argument("--log-file")
    analyze_parser.add_argument("--fake-model", action="store_true")
    analyze_parser.set_defaults(func=_analyze)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except ContractError as exc:
        payload = error_response(exc.message, code=exc.code)
        _dump(payload)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
