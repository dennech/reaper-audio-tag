from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from reaper_panns_runtime.contract import ContractError, SCHEMA_VERSION, validate_request, validate_response
from tests.python.fake_model import analyze_audio_request, error_response


def _json_dump(payload: dict[str, object]) -> None:
    sys.stdout.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def _load_json_file(path: str | None) -> dict[str, object]:
    if not path:
        return json.loads(sys.stdin.read())
    return json.loads(Path(path).read_text(encoding="utf-8"))


def cmd_bootstrap(args: argparse.Namespace) -> int:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "status": "ok",
        "backend": "cpu",
        "installed": True,
        "model_ready": bool(args.model_path),
        "warnings": [],
        "error": None,
    }
    _json_dump(payload)
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    request = {
        "schema_version": SCHEMA_VERSION,
        "temp_audio_path": args.temp_audio_path or "",
        "item_metadata": {"item_id": args.item_id or "probe"},
        "requested_backend": args.requested_backend,
        "timeout_sec": max(1, args.timeout_sec),
    }

    try:
        validate_request(request)
    except ContractError as exc:
        _json_dump(error_response(exc.code, exc.message))
        return 1

    payload = {
        "schema_version": SCHEMA_VERSION,
        "status": "ok",
        "backend": "cpu" if not args.allow_mps else "mps",
        "available_backends": ["cpu"] + (["mps"] if args.allow_mps else []),
        "warnings": [],
        "error": None,
    }
    _json_dump(payload)
    return 0


def cmd_analyze(args: argparse.Namespace) -> int:
    try:
        request = _load_json_file(args.request_file)
        normalized = validate_request(request)
    except ContractError as exc:
        _json_dump(error_response(exc.code, exc.message))
        return 1

    response = analyze_audio_request(normalized, allow_mps=args.allow_mps)
    try:
        validate_response(response)
    except ContractError as exc:
        _json_dump(error_response(exc.code, exc.message, backend=response.get("backend", "cpu")))
        return 1

    _json_dump(response)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fake-panns-cli")
    subparsers = parser.add_subparsers(dest="command", required=True)

    bootstrap = subparsers.add_parser("bootstrap", help="report bootstrap status")
    bootstrap.add_argument("--model-path")
    bootstrap.set_defaults(func=cmd_bootstrap)

    probe = subparsers.add_parser("probe", help="probe backend availability")
    probe.add_argument("--temp-audio-path")
    probe.add_argument("--item-id")
    probe.add_argument("--requested-backend", default="auto", choices=["auto", "cpu", "mps"])
    probe.add_argument("--model-path")
    probe.add_argument("--timeout-sec", type=int, default=30)
    probe.add_argument("--allow-mps", action="store_true")
    probe.set_defaults(func=cmd_probe)

    analyze = subparsers.add_parser("analyze", help="analyze one audio item")
    analyze.add_argument("--request-file", help="JSON request file")
    analyze.add_argument("--allow-mps", action="store_true")
    analyze.set_defaults(func=cmd_analyze)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
