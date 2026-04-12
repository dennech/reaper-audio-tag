from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from .backend import probe_backend
from .bootstrap import bootstrap_runtime
from .config_store import load_config
from .contract import ContractError, error_response, read_json, validate_request, write_json
from .fake_model import analyze_with_fake_model
from .paths import default_paths


def _dump(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, indent=2, ensure_ascii=False, sort_keys=True)
    sys.stdout.write("\n")


def _configured_model_path(config: dict[str, Any]) -> Path:
    return Path(config["model"]["path"])


def _analyze(args: argparse.Namespace) -> int:
    request = validate_request(read_json(args.request_file))
    paths = default_paths()

    try:
        config = load_config(paths)
    except FileNotFoundError:
        payload = error_response(
            "Runtime is not configured yet. Run scripts/bootstrap.command first.",
            code="runtime_not_bootstrapped",
        )
        if args.result_file:
            write_json(args.result_file, payload)
        else:
            _dump(payload)
        return 2

    audio_path = Path(request["temp_audio_path"])
    model_path = _configured_model_path(config)
    requested_backend = request.get("requested_backend") or config["runtime"]["preferred_backend"]

    try:
        if args.fake_model or os.environ.get("REAPER_PANNS_FAKE_MODEL") == "1":
            result = analyze_with_fake_model(audio_path)
            backend = "fake"
            warnings = []
            timing = {"preprocess": 0, "inference": 0, "total": 0}
        else:
            from .model_adapter import analyze_audio_file

            runtime_result = analyze_audio_file(audio_path, model_path, primary_backend=requested_backend)
            result = runtime_result
            backend = runtime_result["backend"]
            warnings = runtime_result["warnings"]
            timing = runtime_result["timing_ms"]

        payload = {
            "schema_version": request["schema_version"],
            "status": "ok",
            "backend": backend,
            "timing_ms": timing,
            "summary": result["summary"],
            "predictions": result["predictions"],
            "highlights": result["highlights"],
            "warnings": warnings,
            "model_status": {
                "name": config["model"]["name"],
                "source": "managed-runtime",
            },
            "item": request["item_metadata"],
        }
    except Exception as exc:
        payload = error_response(str(exc), code="analysis_failed")

    if args.result_file:
        write_json(args.result_file, payload)
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
    analyze_parser.add_argument("--fake-model", action="store_true")
    analyze_parser.set_defaults(func=_analyze)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except ContractError as exc:
        payload = error_response(str(exc), code="contract_error")
        _dump(payload)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
