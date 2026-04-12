#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from tests.python.audio_fixtures import generate_audio_fixtures


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate deterministic audio fixtures for tests.")
    parser.add_argument("--output-dir", required=True, help="Directory to write WAV fixtures into.")
    parser.add_argument("--manifest-name", default="manifest.json", help="Manifest file name.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    output_dir = Path(args.output_dir)
    manifest = generate_audio_fixtures(output_dir)
    manifest_path = output_dir / args.manifest_name
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(manifest_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

