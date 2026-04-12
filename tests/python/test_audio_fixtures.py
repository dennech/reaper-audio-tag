from __future__ import annotations

import json
import tempfile
from pathlib import Path

from tests.python.audio_fixtures import generate_audio_fixtures, sha256_file


def test_generate_audio_fixtures_is_deterministic() -> None:
    with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
        first_manifest = generate_audio_fixtures(Path(first_dir))
        second_manifest = generate_audio_fixtures(Path(second_dir))

        assert first_manifest["schema_version"] == "audio-fixtures/v1"
        assert len(first_manifest["fixtures"]) >= 4
        assert first_manifest["fixtures"][0]["name"] == "silence"

        first_hashes = [fixture["sha256"] for fixture in first_manifest["fixtures"]]
        second_hashes = [fixture["sha256"] for fixture in second_manifest["fixtures"]]
        assert first_hashes == second_hashes

        manifest_path = Path(first_dir) / "manifest.json"
        loaded = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert loaded["fixtures"][1]["name"] == "tone_440hz"


def test_sha256_file_changes_when_content_changes() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "sample.bin"
        path.write_bytes(b"abc123")
        original = sha256_file(path)
        path.write_bytes(b"abc124")
        updated = sha256_file(path)
        assert original != updated
