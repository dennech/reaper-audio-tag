# @noindex
from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

from .backend import backend_candidates
from .labels import load_labels
from .report import build_highlights, build_summary, rank_predictions

TARGET_SAMPLE_RATE = 32000
CLIP_SECONDS = 10
CLIP_SAMPLES = TARGET_SAMPLE_RATE * CLIP_SECONDS


@dataclass
class InferenceBundle:
    summary: str
    predictions: list[dict[str, object]]
    highlights: list[dict[str, object]]
    timing_ms: dict[str, int]
    warnings: list[str]


@dataclass
class InferenceError(RuntimeError):
    message: str
    attempted_backends: list[str]
    warnings: list[str]

    def __str__(self) -> str:
        return self.message


def _load_audio(path: Path) -> np.ndarray:
    try:
        import torch
        import torchaudio.functional as TAF
    except Exception as exc:  # pragma: no cover - optional dependency until real runtime install
        raise RuntimeError("torch and torchaudio are required for real inference.") from exc

    samples, sample_rate = sf.read(path, always_2d=True, dtype="float32")
    mono = samples.mean(axis=1)
    if sample_rate != TARGET_SAMPLE_RATE:
        tensor = torch.from_numpy(mono).unsqueeze(0)
        tensor = TAF.resample(tensor, sample_rate, TARGET_SAMPLE_RATE)
        mono = tensor.squeeze(0).numpy()
    return mono.astype(np.float32, copy=False)


def _segment_audio(audio: np.ndarray) -> np.ndarray:
    if audio.size == 0:
        audio = np.zeros((CLIP_SAMPLES,), dtype=np.float32)
    if audio.size <= CLIP_SAMPLES:
        padded = np.zeros((CLIP_SAMPLES,), dtype=np.float32)
        padded[: audio.size] = audio
        return padded[None, :]

    hop = CLIP_SAMPLES // 2
    starts = list(range(0, audio.size - CLIP_SAMPLES + 1, hop))
    final_start = audio.size - CLIP_SAMPLES
    if starts[-1] != final_start:
        starts.append(final_start)
    return np.stack([audio[start : start + CLIP_SAMPLES] for start in starts]).astype(np.float32)


class PannsModelRunner:
    def __init__(self, checkpoint_path: Path, device: str) -> None:
        try:
            import torch
            from ._vendor.panns.models import Cnn14
        except Exception as exc:  # pragma: no cover - optional dependency until real runtime install
            raise RuntimeError("Real PANNs inference requires torch, torchaudio, and torchlibrosa.") from exc

        self._torch = torch
        self.device = device
        self.labels = load_labels()
        self.model = Cnn14(
            sample_rate=TARGET_SAMPLE_RATE,
            window_size=1024,
            hop_size=320,
            mel_bins=64,
            fmin=50,
            fmax=14000,
            classes_num=len(self.labels),
        )
        checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=True)
        state_dict = checkpoint["model"] if isinstance(checkpoint, dict) and "model" in checkpoint else checkpoint
        if not isinstance(state_dict, dict):
            raise RuntimeError("Unexpected checkpoint structure.")
        self.model.load_state_dict(state_dict)
        self.model.to(device)
        self.model.eval()

    def infer(self, audio_path: Path) -> InferenceBundle:
        load_started = time.perf_counter()
        audio = _load_audio(audio_path)
        preprocess_ms = int((time.perf_counter() - load_started) * 1000)

        batch = _segment_audio(audio)
        batch_tensor = self._torch.from_numpy(batch).to(self.device)

        infer_started = time.perf_counter()
        with self._torch.no_grad():
            output = self.model(batch_tensor, None)
        inference_ms = int((time.perf_counter() - infer_started) * 1000)

        clipwise = output["clipwise_output"].detach().cpu().numpy()
        ranked = rank_predictions(self.labels, clipwise)
        return InferenceBundle(
            summary=build_summary(ranked),
            predictions=[prediction.to_dict() for prediction in ranked],
            highlights=build_highlights(ranked),
            timing_ms={
                "preprocess": preprocess_ms,
                "inference": inference_ms,
                "total": preprocess_ms + inference_ms,
            },
            warnings=[],
        )


def analyze_audio_file(audio_path: Path, checkpoint_path: Path, *, primary_backend: str) -> dict[str, object]:
    warnings: list[str] = []
    attempted_backends = backend_candidates(primary_backend)

    last_error: Exception | None = None
    for backend in attempted_backends:
        try:
            bundle = PannsModelRunner(checkpoint_path, backend).infer(audio_path)
            return {
                "backend": backend,
                "summary": bundle.summary,
                "predictions": bundle.predictions,
                "highlights": bundle.highlights,
                "timing_ms": bundle.timing_ms,
                "attempted_backends": attempted_backends,
                "warnings": warnings + bundle.warnings,
            }
        except Exception as exc:
            last_error = exc
            warnings.append(f"{backend} inference failed: {exc}")

    raise InferenceError(
        str(last_error) if last_error else "Inference failed without an error.",
        attempted_backends=attempted_backends,
        warnings=warnings,
    )
