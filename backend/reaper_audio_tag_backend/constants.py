from __future__ import annotations

SCHEMA_VERSION = "reaper-panns-item-report/v1"
APP_ID = "reaper-panns-item-report"

TARGET_SAMPLE_RATE = 32000
CLIP_SECONDS = 10
CLIP_SAMPLES = TARGET_SAMPLE_RATE * CLIP_SECONDS
HOP_SAMPLES = CLIP_SAMPLES // 2

MODEL_FILENAME = "cnn14_waveform_clipwise_opset17.onnx"
MODEL_SIZE_BYTES = 327331996
MODEL_SHA256 = "deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa"
MODEL_URL = (
    "https://github.com/dennech/reaper-audio-tag/releases/download/"
    "v0.4.1/cnn14_waveform_clipwise_opset17.onnx"
)

POSSIBLE_THRESHOLD = 0.18
TOP_K_SEGMENTS = 3
