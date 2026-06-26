from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def _project_version() -> str:
    match = re.search(r'^version = "([^"]+)"', _read("pyproject.toml"), flags=re.MULTILINE)
    assert match is not None
    return match.group(1)


def test_release_workflow_builds_from_requested_tag_and_refuses_sha_mismatch() -> None:
    workflow = _read(".github/workflows/release.yml")

    assert "ref: ${{ github.event.inputs.tag_name || github.ref }}" in workflow
    assert "fetch-depth: 0" in workflow
    assert "Validate release checkout" in workflow
    assert "RELEASE_TAG_INPUT: ${{ github.event.inputs.tag_name || github.ref_name }}" in workflow
    assert 'release_tag="${RELEASE_TAG_INPUT}"' in workflow
    assert 'release_tag="${{ github.event.inputs.tag_name || github.ref_name }}"' not in workflow
    assert r'^v[0-9]+(\.[0-9]+){2}([-.][0-9A-Za-z.-]+)?$' in workflow
    assert 'tag_sha="$(git rev-list -n 1 "${release_tag}")"' in workflow
    assert 'head_sha="$(git rev-parse HEAD)"' in workflow
    assert "Refusing to upload release assets built from a different commit." in workflow
    assert "exit 1" in workflow


def test_release_workflow_default_tag_points_to_latest_backend_asset_release() -> None:
    workflow = _read(".github/workflows/release.yml")
    assert 'default: "v0.4.9"' in workflow


def test_release_workflow_uploads_only_built_release_assets_to_selected_tag() -> None:
    workflow = _read(".github/workflows/release.yml")

    assert "files: release-assets/*" in workflow
    assert "tag_name: ${{ github.event.inputs.tag_name || github.ref_name }}" in workflow
    assert "overwrite_files: true" in workflow


def test_release_workflow_uploads_verified_model_asset_to_selected_tag() -> None:
    workflow = _read(".github/workflows/release.yml")

    assert "MODEL_FILENAME: cnn14_waveform_clipwise_opset17.onnx" in workflow
    assert "MODEL_SOURCE_TAG: v0.4.9" in workflow
    assert 'gh release download "${MODEL_SOURCE_TAG}"' in workflow
    assert 'actual_size="$(wc -c < "release-assets/${MODEL_FILENAME}"' in workflow
    assert 'echo "${MODEL_SHA256}  release-assets/${MODEL_FILENAME}" | sha256sum -c -' in workflow
    assert "files: release-assets/cnn14_waveform_clipwise_opset17.onnx" in workflow
    assert "Attach cnn14_waveform_clipwise_opset17.onnx" not in workflow


def test_project_versions_and_pinned_model_asset_url_are_intentional() -> None:
    version = _project_version()

    assert f'__version__ = "{version}"' in _read("backend/reaper_audio_tag_backend/__init__.py")
    assert "v0.4.9/cnn14_waveform_clipwise_opset17.onnx" in _read("backend/reaper_audio_tag_backend/constants.py")
    assert f"-- @version {version}" in _read("reaper/REAPER Audio Tag.lua")
    assert "releases/download/v0.4.9/cnn14_waveform_clipwise_opset17.onnx" in _read("reaper/lib/runtime_client.lua")
    assert f'<version name="{version}"' in _read("index.xml")
