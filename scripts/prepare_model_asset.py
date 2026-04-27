#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path


MODEL_FILENAME = "cnn14_waveform_clipwise_opset17.onnx"
MODEL_SIZE_BYTES = 327331996
MODEL_SHA256 = "deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify and stage the ONNX model release asset.")
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(".local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17_coreml_cachekey.onnx"),
    )
    parser.add_argument("--output-dir", type=Path, default=Path("dist/release-assets"))
    args = parser.parse_args()

    if not args.source.exists():
        raise SystemExit(f"Model source was not found: {args.source}")

    size = args.source.stat().st_size
    if size != MODEL_SIZE_BYTES:
        raise SystemExit(f"Unexpected model size: {size} != {MODEL_SIZE_BYTES}")

    digest = sha256_file(args.source)
    if digest != MODEL_SHA256:
        raise SystemExit(f"Unexpected model SHA-256: {digest} != {MODEL_SHA256}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    target = args.output_dir / MODEL_FILENAME
    shutil.copyfile(args.source, target)
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
