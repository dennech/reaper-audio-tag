from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_SAMPLE_RATE = 16_000
DEFAULT_DURATION_SEC = 1.5
DEFAULT_CHANNELS = 1
DEFAULT_SAMPLE_WIDTH = 2


@dataclass(frozen=True)
class FixtureSpec:
    name: str
    kind: str
    duration_sec: float = DEFAULT_DURATION_SEC
    sample_rate: int = DEFAULT_SAMPLE_RATE
    channels: int = DEFAULT_CHANNELS
    seed: int = 17
    expected_tags: tuple[str, ...] = ()


FIXTURE_SPECS: tuple[FixtureSpec, ...] = (
    FixtureSpec(
        name="silence",
        kind="silence",
        expected_tags=("silence", "low energy", "room tone"),
    ),
    FixtureSpec(
        name="tone_440hz",
        kind="tone",
        seed=23,
        expected_tags=("sine tone", "steady signal", "tonal sound"),
    ),
    FixtureSpec(
        name="white_noise",
        kind="noise",
        seed=29,
        expected_tags=("broadband noise", "hiss", "texture"),
    ),
    FixtureSpec(
        name="mix_tone_noise",
        kind="mix",
        seed=31,
        expected_tags=("mixed content", "steady tone", "noise bed"),
    ),
    FixtureSpec(
        name="impulse_train",
        kind="impulse",
        seed=37,
        expected_tags=("transient", "clicks", "percussive"),
    ),
)


def _clip_sample(value: float) -> int:
    value = max(-1.0, min(1.0, value))
    return int(round(value * 32767.0))


def _tone_samples(spec: FixtureSpec, frequency: float, amplitude: float) -> list[int]:
    total = int(round(spec.duration_sec * spec.sample_rate))
    samples = []
    for index in range(total):
        phase = 2.0 * math.pi * frequency * index / spec.sample_rate
        samples.append(_clip_sample(math.sin(phase) * amplitude))
    return samples


def _noise_samples(spec: FixtureSpec, amplitude: float) -> list[int]:
    rng = random.Random(spec.seed)
    total = int(round(spec.duration_sec * spec.sample_rate))
    return [_clip_sample(rng.uniform(-amplitude, amplitude)) for _ in range(total)]


def _silence_samples(spec: FixtureSpec) -> list[int]:
    total = int(round(spec.duration_sec * spec.sample_rate))
    return [0 for _ in range(total)]


def _mix_samples(spec: FixtureSpec) -> list[int]:
    tone = _tone_samples(spec, frequency=660.0, amplitude=0.36)
    noise = _noise_samples(spec, amplitude=0.18)
    return [_clip_sample((tone[index] / 32767.0) + (noise[index] / 32767.0)) for index in range(len(tone))]


def _impulse_samples(spec: FixtureSpec) -> list[int]:
    total = int(round(spec.duration_sec * spec.sample_rate))
    samples = [0 for _ in range(total)]
    spacing = max(1, spec.sample_rate // 12)
    for index in range(0, total, spacing):
        samples[index] = _clip_sample(0.85)
    return samples


def build_samples(spec: FixtureSpec) -> list[int]:
    if spec.kind == "silence":
        return _silence_samples(spec)
    if spec.kind == "tone":
        return _tone_samples(spec, frequency=440.0, amplitude=0.42)
    if spec.kind == "noise":
        return _noise_samples(spec, amplitude=0.32)
    if spec.kind == "mix":
        return _mix_samples(spec)
    if spec.kind == "impulse":
        return _impulse_samples(spec)
    raise ValueError(f"unsupported fixture kind: {spec.kind}")


def write_wav(path: Path, samples: list[int], sample_rate: int, channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(DEFAULT_SAMPLE_WIDTH)
        wav.setframerate(sample_rate)
        frame = struct.pack("<" + "h" * len(samples), *samples)
        wav.writeframes(frame)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def generate_audio_fixtures(output_dir: Path) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    fixtures: list[dict[str, Any]] = []

    for spec in FIXTURE_SPECS:
        wav_path = output_dir / f"{spec.name}.wav"
        samples = build_samples(spec)
        write_wav(wav_path, samples, spec.sample_rate, spec.channels)
        fixtures.append(
            {
                "name": spec.name,
                "kind": spec.kind,
                "path": str(wav_path),
                "duration_sec": spec.duration_sec,
                "sample_rate": spec.sample_rate,
                "channels": spec.channels,
                "sha256": sha256_file(wav_path),
                "expected_tags": list(spec.expected_tags),
            }
        )

    manifest = {
        "schema_version": "audio-fixtures/v1",
        "generator": "tests.python.audio_fixtures",
        "sample_rate": DEFAULT_SAMPLE_RATE,
        "channels": DEFAULT_CHANNELS,
        "fixtures": fixtures,
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def load_audio_samples(path: Path) -> tuple[int, list[int]]:
    with wave.open(str(path), "rb") as wav:
        sample_rate = wav.getframerate()
        channels = wav.getnchannels()
        frames = wav.readframes(wav.getnframes())

    total_samples = len(frames) // DEFAULT_SAMPLE_WIDTH
    samples = list(struct.unpack("<" + "h" * total_samples, frames))
    if channels > 1:
        samples = samples[::channels]
    return sample_rate, samples


def describe_audio(path: Path) -> dict[str, Any]:
    sample_rate, samples = load_audio_samples(path)
    if not samples:
        return {
            "sample_rate": sample_rate,
            "sample_count": 0,
            "duration_sec": 0.0,
            "peak": 0.0,
            "rms": 0.0,
            "zero_crossings": 0,
            "mean_abs": 0.0,
        }

    peak = max(abs(sample) for sample in samples) / 32767.0
    mean_square = sum((sample / 32767.0) ** 2 for sample in samples) / len(samples)
    rms = math.sqrt(mean_square)
    mean_abs = sum(abs(sample) for sample in samples) / (len(samples) * 32767.0)
    zero_crossings = sum(
        1
        for left, right in zip(samples, samples[1:])
        if (left < 0 <= right) or (left > 0 >= right)
    )
    return {
        "sample_rate": sample_rate,
        "sample_count": len(samples),
        "duration_sec": len(samples) / sample_rate,
        "peak": peak,
        "rms": rms,
        "zero_crossings": zero_crossings,
        "mean_abs": mean_abs,
    }
