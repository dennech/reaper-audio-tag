# @noindex
from __future__ import annotations

import math
from pathlib import Path
import struct
import wave

from .labels import load_labels
from .report import build_highlights, build_summary, rank_predictions


def analyze_with_fake_model(audio_path: Path) -> dict[str, object]:
    with wave.open(str(audio_path), "rb") as handle:
        sample_rate = handle.getframerate()
        channels = handle.getnchannels()
        frames = handle.readframes(handle.getnframes())

    if not frames:
        mono = []
    else:
        sample_count = len(frames) // 2
        unpacked = struct.unpack("<" + ("h" * sample_count), frames)
        if channels > 1:
            mono = []
            for index in range(0, len(unpacked), channels):
                total = 0
                for channel in range(channels):
                    total += unpacked[index + channel]
                mono.append(total / channels / 32767.0)
        else:
            mono = [sample / 32767.0 for sample in unpacked]

    duration = len(mono) / sample_rate if sample_rate else 0.0
    energy = sum(abs(sample) for sample in mono) / len(mono) if mono else 0.0

    labels = load_labels()
    scores = [0.0 for _ in labels]
    seeded = min(0.95, 0.15 + energy * 3.0)
    mapping = {
        "Speech": seeded if duration > 0.5 else 0.05,
        "Music": min(0.85, 0.1 + math.sqrt(max(energy, 0.0))),
        "Silence": max(0.0, 0.9 - energy * 8.0),
        "Inside, small room": min(0.7, 0.2 + duration / 20.0),
    }
    for index, label in enumerate(labels):
        scores[index] = mapping.get(label, 0.01)

    ranked = rank_predictions(labels, scores)
    return {
        "summary": build_summary(ranked),
        "predictions": [prediction.to_dict() for prediction in ranked],
        "highlights": build_highlights(ranked),
    }
