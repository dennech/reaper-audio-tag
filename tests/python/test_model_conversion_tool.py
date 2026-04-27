from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from scripts import export_cnn14_to_onnx


ROOT = Path(__file__).resolve().parents[2]


def test_export_cnn14_to_onnx_help_is_lightweight() -> None:
    result = subprocess.run(
        [sys.executable, "scripts/export_cnn14_to_onnx.py", "--help"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    assert "Cnn14_mAP=0.431.pth" in result.stdout
    assert "maintainer/developer tool" in result.stdout
    assert "--panns-repo" in result.stdout


def test_export_cnn14_to_onnx_sha256_helper(tmp_path: Path) -> None:
    payload = tmp_path / "payload.bin"
    payload.write_bytes(b"panns")

    assert export_cnn14_to_onnx.sha256_file(payload) == "616a1bcb9ad9f700cccf1ae40c2664bedcdd9c9288e4ee6c2f96f36f9e77debd"
