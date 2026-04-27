from __future__ import annotations

import sys
from pathlib import Path
from types import SimpleNamespace

from reaper_audio_tag_backend import onnx_runner


class _FakeSessionOptions:
    def __init__(self) -> None:
        self.graph_optimization_level = None


class _FakeOrt:
    def __init__(self, providers: list[str]) -> None:
        self._providers = providers
        self.GraphOptimizationLevel = SimpleNamespace(ORT_ENABLE_ALL="all")
        self.created_sessions: list[dict[str, object]] = []

    def get_available_providers(self) -> list[str]:
        return list(self._providers)

    def SessionOptions(self) -> _FakeSessionOptions:
        return _FakeSessionOptions()

    def InferenceSession(self, model_path: str, *, sess_options, providers):
        payload = {
            "model_path": model_path,
            "sess_options": sess_options,
            "providers": providers,
        }
        self.created_sessions.append(payload)
        return payload


def _with_fake_ort(fake_ort: _FakeOrt, system_name: str, callback):
    original_ort = sys.modules.get("onnxruntime")
    original_system = onnx_runner.platform.system
    sys.modules["onnxruntime"] = fake_ort  # type: ignore[assignment]
    onnx_runner.platform.system = lambda: system_name
    try:
        return callback(fake_ort)
    finally:
        onnx_runner.platform.system = original_system
        if original_ort is None:
            sys.modules.pop("onnxruntime", None)
        else:
            sys.modules["onnxruntime"] = original_ort


def test_provider_candidates_prefer_coreml_mlprogram_then_cpu_on_macos() -> None:
    def run(_fake_ort: _FakeOrt):
        candidates = onnx_runner.provider_candidates("auto")
        assert [name for name, _provider in candidates] == ["coreml", "cpu"]
        coreml_provider = candidates[0][1]
        assert coreml_provider[0] == "CoreMLExecutionProvider"
        assert coreml_provider[1]["ModelFormat"] == "MLProgram"
        assert coreml_provider[1]["MLComputeUnits"] == "ALL"
        assert coreml_provider[1]["RequireStaticInputShapes"] == "1"

    _with_fake_ort(_FakeOrt(["CoreMLExecutionProvider", "CPUExecutionProvider"]), "Darwin", run)


def test_provider_candidates_fall_back_to_cpu_when_native_provider_is_unavailable() -> None:
    def run(_fake_ort: _FakeOrt):
        assert onnx_runner.provider_candidates("auto") == [("cpu", "CPUExecutionProvider")]
        assert onnx_runner.provider_candidates("coreml") == [("cpu", "CPUExecutionProvider")]

    _with_fake_ort(_FakeOrt(["CPUExecutionProvider"]), "Darwin", run)


def test_provider_candidates_prefer_directml_then_cpu_on_windows() -> None:
    def run(_fake_ort: _FakeOrt):
        assert onnx_runner.provider_candidates("auto") == [
            ("directml", "DmlExecutionProvider"),
            ("cpu", "CPUExecutionProvider"),
        ]

    _with_fake_ort(_FakeOrt(["DmlExecutionProvider", "CPUExecutionProvider"]), "Windows", run)


def test_cpu_session_does_not_register_cpu_provider_twice() -> None:
    def run(fake_ort: _FakeOrt):
        onnx_runner._session(Path("/tmp/model.onnx"), "CPUExecutionProvider", None)
        assert fake_ort.created_sessions[-1]["providers"] == ["CPUExecutionProvider"]

    _with_fake_ort(_FakeOrt(["CPUExecutionProvider"]), "Darwin", run)


def test_coreml_session_uses_cache_directory_and_cpu_fallback() -> None:
    def run(fake_ort: _FakeOrt):
        onnx_runner._session(
            Path("/tmp/model.onnx"),
            (
                "CoreMLExecutionProvider",
                {
                    "ModelFormat": "MLProgram",
                    "MLComputeUnits": "ALL",
                    "RequireStaticInputShapes": "1",
                },
            ),
            Path("/tmp/reaper-audio-tag-coreml-cache"),
        )
        providers = fake_ort.created_sessions[-1]["providers"]
        assert providers[0][0] == "CoreMLExecutionProvider"
        assert providers[0][1]["ModelCacheDirectory"] == "/tmp/reaper-audio-tag-coreml-cache"
        assert providers[1] == "CPUExecutionProvider"

    _with_fake_ort(_FakeOrt(["CoreMLExecutionProvider", "CPUExecutionProvider"]), "Darwin", run)
