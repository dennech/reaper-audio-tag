from __future__ import annotations

import argparse
import traceback
from pathlib import Path
from typing import Any

from . import __version__
from .constants import MODEL_SHA256, MODEL_SIZE_BYTES, MODEL_URL, SCHEMA_VERSION
from .json_io import read_json, write_json
from .model_store import DownloadModelError, download_verified, friendly_download_error, verify_file


def _log(path: str | Path | None, message: str) -> None:
    if not path:
        return
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("a", encoding="utf-8") as handle:
        handle.write(message.rstrip() + "\n")


def response_payload(
    *,
    status: str,
    backend: str,
    stage: str = "runtime",
    attempted_backends: list[str] | None = None,
    timing_ms: dict[str, int] | None = None,
    summary: str = "",
    predictions: list[dict[str, Any]] | None = None,
    highlights: list[dict[str, Any]] | None = None,
    warnings: list[str] | None = None,
    model_status: dict[str, Any] | None = None,
    item: dict[str, Any] | None = None,
    error: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "status": status,
        "stage": stage,
        "backend": backend,
        "attempted_backends": attempted_backends or [],
        "timing_ms": timing_ms or {"preprocess": 0, "inference": 0, "total": 0},
        "summary": summary,
        "predictions": predictions or [],
        "highlights": highlights or [],
        "warnings": warnings or [],
        "model_status": model_status or {"name": "Cnn14 ONNX", "source": "downloaded model"},
        "item": item or {},
        "error": error,
    }


def _write_error(args, code: str, message: str, *, item: dict[str, Any] | None = None, warnings: list[str] | None = None) -> int:
    payload = response_payload(
        status="error",
        backend="cpu",
        attempted_backends=[],
        summary="No analysis summary is available.",
        warnings=warnings or [],
        item=item or {},
        error={"code": code, "message": message},
    )
    write_json(args.result_file, payload)
    _log(getattr(args, "log_file", None), f"ERROR {code}: {message}")
    return 1


def cmd_analyze(args) -> int:
    try:
        from .onnx_runner import analyze

        request = read_json(args.request_file)
        item = request.get("item_metadata") if isinstance(request.get("item_metadata"), dict) else {}
        if request.get("schema_version") != SCHEMA_VERSION:
            return _write_error(args, "schema_mismatch", "Unsupported request schema.", item=item)
        result = analyze(
            request["temp_audio_path"],
            args.model_file,
            args.labels_file,
            requested_backend=request.get("requested_backend") or "auto",
            cache_dir=args.cache_dir,
        )
        payload = response_payload(
            status="ok",
            backend=str(result["backend"]),
            attempted_backends=list(result["attempted_backends"]),
            timing_ms=dict(result["timing_ms"]),
            summary=str(result["summary"]),
            predictions=list(result["predictions"]),
            highlights=list(result["highlights"]),
            warnings=list(result["warnings"]),
            item=item,
        )
        write_json(args.result_file, payload)
        _log(args.log_file, f"Analysis finished with backend={payload['backend']}")
        return 0
    except Exception as exc:
        _log(args.log_file, traceback.format_exc())
        item = {}
        try:
            request = read_json(args.request_file)
            if isinstance(request.get("item_metadata"), dict):
                item = request["item_metadata"]
        except Exception:
            pass
        return _write_error(args, "analysis_failed", str(exc), item=item)


def cmd_download_model(args) -> int:
    try:
        output = download_verified(
            url=args.url or MODEL_URL,
            output=args.output,
            sha256=args.sha256 or MODEL_SHA256,
            size=int(args.size or MODEL_SIZE_BYTES),
            progress_file=args.progress_file,
        )
        payload = {"status": "ok", "path": str(output), "size": output.stat().st_size, "sha256": args.sha256 or MODEL_SHA256}
        write_json(args.result_file, payload)
        _log(args.log_file, f"Model ready: {output}")
        return 0
    except Exception as exc:
        _log(args.log_file, traceback.format_exc())
        error = exc if isinstance(exc, DownloadModelError) else friendly_download_error(exc)
        write_json(
            args.result_file,
            {
                "status": "error",
                "error": {
                    "code": error.code,
                    "message": error.user_message,
                    "detail": error.detail,
                },
            },
        )
        return 1


def cmd_verify_model(args) -> int:
    ok, reason = verify_file(args.model_file, sha256=args.sha256 or MODEL_SHA256, size=int(args.size or MODEL_SIZE_BYTES))
    write_json(args.result_file, {"status": "ok" if ok else "error", "reason": reason})
    return 0 if ok else 1


def cmd_self_test(args) -> int:
    try:
        import onnxruntime as ort

        payload = {"status": "ok", "version": __version__, "providers": ort.get_available_providers()}
        write_json(args.result_file, payload)
        return 0
    except Exception as exc:
        write_json(args.result_file, {"status": "error", "error": str(exc)})
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="reaper-audio-tag-backend")
    parser.add_argument("--version", action="version", version=__version__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    analyze_parser = subparsers.add_parser("analyze")
    analyze_parser.add_argument("--request-file", required=True)
    analyze_parser.add_argument("--result-file", required=True)
    analyze_parser.add_argument("--log-file", required=True)
    analyze_parser.add_argument("--model-file", required=True)
    analyze_parser.add_argument("--labels-file", required=True)
    analyze_parser.add_argument("--cache-dir", required=True)
    analyze_parser.set_defaults(func=cmd_analyze)

    download_parser = subparsers.add_parser("download-model")
    download_parser.add_argument("--url", default=MODEL_URL)
    download_parser.add_argument("--output", required=True)
    download_parser.add_argument("--sha256", default=MODEL_SHA256)
    download_parser.add_argument("--size", type=int, default=MODEL_SIZE_BYTES)
    download_parser.add_argument("--progress-file", required=True)
    download_parser.add_argument("--result-file", required=True)
    download_parser.add_argument("--log-file", required=True)
    download_parser.set_defaults(func=cmd_download_model)

    verify_parser = subparsers.add_parser("verify-model")
    verify_parser.add_argument("--model-file", required=True)
    verify_parser.add_argument("--sha256", default=MODEL_SHA256)
    verify_parser.add_argument("--size", type=int, default=MODEL_SIZE_BYTES)
    verify_parser.add_argument("--result-file", required=True)
    verify_parser.set_defaults(func=cmd_verify_model)

    self_test_parser = subparsers.add_parser("self-test")
    self_test_parser.add_argument("--result-file", required=True)
    self_test_parser.set_defaults(func=cmd_self_test)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
