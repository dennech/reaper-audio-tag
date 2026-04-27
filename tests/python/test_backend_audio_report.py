from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

from reaper_audio_tag_backend.audio import load_reaper_wav, segment_audio
from reaper_audio_tag_backend.constants import CLIP_SAMPLES, TARGET_SAMPLE_RATE
from reaper_audio_tag_backend.labels import load_labels
from reaper_audio_tag_backend.report import build_highlights, build_summary, rank_predictions


def write_wav(path: Path, samples: np.ndarray) -> None:
    pcm = np.clip(samples, -1, 1)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(TARGET_SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def test_load_reaper_wav_and_segment_short_clip(tmp_path: Path) -> None:
    wav = tmp_path / "clip.wav"
    write_wav(wav, np.ones(1024, dtype=np.float32) * 0.25)

    audio = load_reaper_wav(wav)
    assert audio.shape == (1024,)
    assert 0.24 < float(audio.mean()) < 0.26

    batch = segment_audio(audio)
    assert batch.shape == (1, CLIP_SAMPLES)
    assert 0.24 < float(batch[0, :1024].mean()) < 0.26
    assert float(batch[0, 2048:].max()) == 0.0


def test_report_ranking_matches_existing_contract() -> None:
    labels = ["Speech", "Music", "Drum"]
    scores = np.array([[0.1, 0.9, 0.2], [0.4, 0.8, 0.1]], dtype=np.float32)

    ranked = rank_predictions(labels, scores)
    assert ranked[0].label == "Music"
    assert ranked[0].bucket == "strong"
    assert ranked[1].label == "Speech"
    assert build_summary(ranked) == "Top detected tags: Music and Speech."
    assert build_highlights(ranked)[0]["label"] == "Music"


def test_labels_load_from_reaper_data_file() -> None:
    labels = load_labels("reaper/data/class_labels_indices.csv")
    assert labels[0] == "Speech"
    assert "Music" in labels
    assert len(labels) > 500
