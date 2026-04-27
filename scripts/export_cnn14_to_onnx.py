#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


DEFAULT_OUTPUT = Path(".local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17.onnx")
DEFAULT_INPUT_SAMPLES = 320_000
DEFAULT_OPSET = 17
DEFAULT_SAMPLE_RATE = 32_000
DEFAULT_CACHE_KEY_PREFIX = "reaper-audio-tag-cnn14-waveform-opset17"
PANN_CHECKPOINT_NAME = "Cnn14_mAP=0.431.pth"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Export the upstream PANNs Cnn14 checkpoint to the ONNX waveform model "
            "used by REAPER Audio Tag. This is a maintainer/developer tool; normal "
            "ReaPack users do not need it."
        )
    )
    parser.add_argument(
        "--checkpoint",
        type=Path,
        required=True,
        help=f"Path to the upstream {PANN_CHECKPOINT_NAME} checkpoint.",
    )
    parser.add_argument(
        "--panns-repo",
        type=Path,
        required=True,
        help="Path to a local clone of https://github.com/qiuqiangkong/audioset_tagging_cnn.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output ONNX path. Default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument("--opset", type=int, default=DEFAULT_OPSET)
    parser.add_argument("--sample-rate", type=int, default=DEFAULT_SAMPLE_RATE)
    parser.add_argument("--input-samples", type=int, default=DEFAULT_INPUT_SAMPLES)
    parser.add_argument(
        "--cache-key",
        default=None,
        help="Optional ONNX metadata CACHE_KEY for ONNX Runtime CoreML caching.",
    )
    parser.add_argument(
        "--sidecar-json",
        type=Path,
        default=None,
        help="Optional conversion metadata JSON path. Defaults to OUTPUT.with_suffix('.json').",
    )
    return parser


def _load_cnn14_class(panns_repo: Path) -> Any:
    pytorch_dir = panns_repo / "pytorch"
    if not pytorch_dir.is_dir():
        raise SystemExit(f"PANNs repo does not contain a pytorch/ directory: {panns_repo}")

    sys.path.insert(0, str(panns_repo))
    sys.path.insert(0, str(pytorch_dir))
    try:
        from models import Cnn14  # type: ignore
    except Exception as exc:  # pragma: no cover - depends on external PANNs checkout
        raise SystemExit(
            "Could not import Cnn14 from the PANNs repo. Install the PANNs export "
            "dependencies first, including torch and torchlibrosa."
        ) from exc
    return Cnn14


def _checkpoint_state_dict(torch_module: Any, checkpoint_path: Path) -> dict[str, Any]:
    checkpoint = torch_module.load(checkpoint_path, map_location="cpu")
    if isinstance(checkpoint, dict):
        for key in ("model", "state_dict"):
            candidate = checkpoint.get(key)
            if isinstance(candidate, dict):
                return candidate
    if isinstance(checkpoint, dict):
        return checkpoint
    raise SystemExit(f"Unsupported checkpoint payload in {checkpoint_path}")


def _add_onnx_metadata(onnx_path: Path, metadata: dict[str, str]) -> None:
    import onnx  # type: ignore

    model = onnx.load(str(onnx_path))
    existing = {entry.key: entry for entry in model.metadata_props}
    for key, value in metadata.items():
        if key in existing:
            existing[key].value = value
        else:
            entry = model.metadata_props.add()
            entry.key = key
            entry.value = value
    onnx.save(model, str(onnx_path))


def export(args: argparse.Namespace) -> dict[str, Any]:
    if not args.checkpoint.exists():
        raise SystemExit(f"Checkpoint was not found: {args.checkpoint}")
    if args.checkpoint.name != PANN_CHECKPOINT_NAME:
        raise SystemExit(f"Expected checkpoint filename {PANN_CHECKPOINT_NAME}, got {args.checkpoint.name}")

    try:
        import torch  # type: ignore
    except Exception as exc:  # pragma: no cover - depends on optional export env
        raise SystemExit("PyTorch is required for export. Install the optional model-export dependencies first.") from exc

    Cnn14 = _load_cnn14_class(args.panns_repo)
    model = Cnn14(
        sample_rate=args.sample_rate,
        window_size=1024,
        hop_size=320,
        mel_bins=64,
        fmin=50,
        fmax=14_000,
        classes_num=527,
    )
    model.load_state_dict(_checkpoint_state_dict(torch, args.checkpoint))
    model.eval()

    class ClipwiseOutput(torch.nn.Module):
        def __init__(self, wrapped: Any) -> None:
            super().__init__()
            self.wrapped = wrapped

        def forward(self, waveform: Any) -> Any:
            output = self.wrapped(waveform)
            return output["clipwise_output"]

    wrapped_model = ClipwiseOutput(model)
    dummy_waveform = torch.zeros(1, args.input_samples, dtype=torch.float32)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        wrapped_model,
        dummy_waveform,
        str(args.output),
        input_names=["waveform"],
        output_names=["clipwise_output"],
        opset_version=args.opset,
        do_constant_folding=True,
    )

    checkpoint_sha256 = sha256_file(args.checkpoint)
    cache_key = args.cache_key or f"{DEFAULT_CACHE_KEY_PREFIX}-{checkpoint_sha256[:12]}"
    _add_onnx_metadata(
        args.output,
        {
            "CACHE_KEY": cache_key,
            "source_model": "PANNs Cnn14",
            "source_checkpoint": PANN_CHECKPOINT_NAME,
            "source_checkpoint_sha256": checkpoint_sha256,
            "sample_rate": str(args.sample_rate),
            "input_samples": str(args.input_samples),
            "opset": str(args.opset),
        },
    )

    onnx_sha256 = sha256_file(args.output)
    metadata = {
        "output": str(args.output),
        "output_size_bytes": args.output.stat().st_size,
        "output_sha256": onnx_sha256,
        "cache_key": cache_key,
        "checkpoint": str(args.checkpoint),
        "checkpoint_sha256": checkpoint_sha256,
        "panns_repo": str(args.panns_repo),
        "source_checkpoint": PANN_CHECKPOINT_NAME,
        "sample_rate": args.sample_rate,
        "input_samples": args.input_samples,
        "opset": args.opset,
    }

    sidecar = args.sidecar_json or args.output.with_suffix(".json")
    sidecar.parent.mkdir(parents=True, exist_ok=True)
    sidecar.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metadata["sidecar_json"] = str(sidecar)
    return metadata


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    metadata = export(args)
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
