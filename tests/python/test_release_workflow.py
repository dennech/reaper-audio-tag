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
    assert 'release_tag="${{ github.event.inputs.tag_name || github.ref_name }}"' in workflow
    assert 'tag_sha="$(git rev-list -n 1 "${release_tag}")"' in workflow
    assert 'head_sha="$(git rev-parse HEAD)"' in workflow
    assert "Refusing to upload release assets built from a different commit." in workflow
    assert "exit 1" in workflow


def test_release_workflow_default_tag_matches_project_version() -> None:
    workflow = _read(".github/workflows/release.yml")
    assert f'default: "v{_project_version()}"' in workflow


def test_release_workflow_uploads_only_built_release_assets_to_selected_tag() -> None:
    workflow = _read(".github/workflows/release.yml")

    assert "files: release-assets/*" in workflow
    assert "tag_name: ${{ github.event.inputs.tag_name || github.ref_name }}" in workflow
    assert "overwrite_files: true" in workflow


def test_release_workflow_uploads_verified_model_asset_to_selected_tag() -> None:
    workflow = _read(".github/workflows/release.yml")

    assert "MODEL_FILENAME: cnn14_waveform_clipwise_opset17.onnx" in workflow
    assert "MODEL_SOURCE_TAG: v0.4.4" in workflow
    assert 'gh release download "${MODEL_SOURCE_TAG}"' in workflow
    assert 'actual_size="$(wc -c < "release-assets/${MODEL_FILENAME}"' in workflow
    assert 'echo "${MODEL_SHA256}  release-assets/${MODEL_FILENAME}" | sha256sum -c -' in workflow
    assert "files: release-assets/cnn14_waveform_clipwise_opset17.onnx" in workflow
    assert "Attach cnn14_waveform_clipwise_opset17.onnx" not in workflow


def test_project_backend_lua_and_model_urls_use_the_same_release_version() -> None:
    version = _project_version()

    assert f'__version__ = "{version}"' in _read("backend/reaper_audio_tag_backend/__init__.py")
    assert f"v{version}/cnn14_waveform_clipwise_opset17.onnx" in _read("backend/reaper_audio_tag_backend/constants.py")
    assert f"-- @version {version}" in _read("reaper/REAPER Audio Tag.lua")
    assert f"releases/download/v{version}/cnn14_waveform_clipwise_opset17.onnx" in _read("reaper/lib/runtime_client.lua")
    assert f'<version name="{version}"' in _read("index.xml")
