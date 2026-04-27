from __future__ import annotations

import platform
import time
from pathlib import Path

import numpy as np

from .audio import load_reaper_wav, segment_audio
from .labels import load_labels
from .report import build_highlights, build_summary, rank_predictions


def provider_candidates(requested: str) -> list[tuple[str, object]]:
    import onnxruntime as ort

    available = set(ort.get_available_providers())
    requested = requested or "auto"
    candidates: list[tuple[str, object]] = []
    system = platform.system().lower()

    if requested in ("auto", "coreml") and system == "darwin" and "CoreMLExecutionProvider" in available:
        candidates.append(
            (
                "coreml",
                (
                    "CoreMLExecutionProvider",
                    {
                        "ModelFormat": "MLProgram",
                        "MLComputeUnits": "ALL",
                        "RequireStaticInputShapes": "1",
                    },
                ),
            )
        )
    if requested in ("auto", "directml") and system == "windows" and "DmlExecutionProvider" in available:
        candidates.append(("directml", "DmlExecutionProvider"))
    if requested in ("auto", "cpu", "coreml", "directml") and "CPUExecutionProvider" in available:
        candidates.append(("cpu", "CPUExecutionProvider"))
    if not candidates:
        candidates.append(("cpu", "CPUExecutionProvider"))
    if requested == "cpu":
        return [("cpu", "CPUExecutionProvider")]
    return candidates


def _session(model_path: Path, provider: object, cache_dir: Path | None):
    import onnxruntime as ort

    options = ort.SessionOptions()
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    if isinstance(provider, tuple) and provider[0] == "CoreMLExecutionProvider" and cache_dir:
        provider_options = dict(provider[1])
        provider_options["ModelCacheDirectory"] = str(cache_dir)
        provider = (provider[0], provider_options)
    return ort.InferenceSession(str(model_path), sess_options=options, providers=[provider, "CPUExecutionProvider"])


def analyze(audio_path: str | Path, model_path: str | Path, labels_path: str | Path, *, requested_backend: str, cache_dir: str | Path | None) -> dict[str, object]:
    preprocess_started = time.perf_counter()
    audio = load_reaper_wav(audio_path)
    batch = segment_audio(audio)
    preprocess_ms = int((time.perf_counter() - preprocess_started) * 1000)

    labels = load_labels(labels_path)
    attempted: list[str] = []
    warnings: list[str] = []
    last_error: Exception | None = None
    cache_path = Path(cache_dir) if cache_dir else None
    if cache_path:
        cache_path.mkdir(parents=True, exist_ok=True)

    for backend_name, provider in provider_candidates(requested_backend):
        attempted.append(backend_name)
        try:
            session = _session(Path(model_path), provider, cache_path)
            input_name = session.get_inputs()[0].name
            output_names = [output.name for output in session.get_outputs()]
            preferred_output = "clipwise_output" if "clipwise_output" in output_names else output_names[0]

            inference_started = time.perf_counter()
            rows = []
            for segment in batch:
                output = session.run([preferred_output], {input_name: segment[np.newaxis, :].astype(np.float32, copy=False)})[0]
                rows.append(np.asarray(output, dtype=np.float32).reshape(-1))
            inference_ms = int((time.perf_counter() - inference_started) * 1000)

            scores = np.stack(rows)
            ranked = rank_predictions(labels, scores)
            return {
                "backend": backend_name,
                "attempted_backends": attempted,
                "warnings": warnings,
                "timing_ms": {
                    "preprocess": preprocess_ms,
                    "inference": inference_ms,
                    "total": preprocess_ms + inference_ms,
                },
                "summary": build_summary(ranked),
                "predictions": [prediction.to_dict() for prediction in ranked],
                "highlights": build_highlights(ranked),
            }
        except Exception as exc:
            last_error = exc
            warnings.append(f"{backend_name} failed: {exc}")

    raise RuntimeError(str(last_error) if last_error else "No ONNX Runtime backend could run the model.")
