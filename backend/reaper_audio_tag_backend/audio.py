from __future__ import annotations

from pathlib import Path
import wave

import numpy as np

from .constants import CLIP_SAMPLES, HOP_SAMPLES, TARGET_SAMPLE_RATE


def load_reaper_wav(path: str | Path) -> np.ndarray:
    """Read the mono 32 kHz 16-bit PCM WAV produced by the Lua exporter."""
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        sample_rate = handle.getframerate()
        sample_width = handle.getsampwidth()
        frames = handle.getnframes()
        raw = handle.readframes(frames)

    if sample_rate != TARGET_SAMPLE_RATE:
        raise RuntimeError(f"Expected {TARGET_SAMPLE_RATE} Hz WAV from REAPER, got {sample_rate} Hz.")
    if sample_width != 2:
        raise RuntimeError(f"Expected 16-bit PCM WAV from REAPER, got sample width {sample_width}.")
    if channels < 1:
        raise RuntimeError("WAV file has no audio channels.")

    samples = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if channels > 1:
        samples = samples.reshape((-1, channels)).mean(axis=1)
    return samples.astype(np.float32, copy=False)


def segment_audio(audio: np.ndarray) -> np.ndarray:
    if audio.size == 0:
        audio = np.zeros((CLIP_SAMPLES,), dtype=np.float32)
    if audio.size <= CLIP_SAMPLES:
        padded = np.zeros((CLIP_SAMPLES,), dtype=np.float32)
        padded[: audio.size] = audio
        return padded[None, :]

    starts = list(range(0, audio.size - CLIP_SAMPLES + 1, HOP_SAMPLES))
    final_start = audio.size - CLIP_SAMPLES
    if starts[-1] != final_start:
        starts.append(final_start)
    return np.stack([audio[start : start + CLIP_SAMPLES] for start in starts]).astype(np.float32)
