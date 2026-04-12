from __future__ import annotations

from pathlib import Path

from reaper_panns_runtime.backend import backend_candidates
from reaper_panns_runtime.model_adapter import InferenceBundle, analyze_audio_file
from reaper_panns_runtime.report import build_highlights, build_summary, rank_predictions
from unittest.mock import patch


def test_backend_candidates_for_auto_prefers_mps_then_cpu() -> None:
    assert backend_candidates("auto") == ["mps", "cpu"]


def test_analyze_audio_file_auto_falls_back_from_mps_to_cpu() -> None:
    class FakeRunner:
        def __init__(self, checkpoint_path: Path, device: str) -> None:
            self.device = device

        def infer(self, audio_path: Path) -> InferenceBundle:
            if self.device == "mps":
                raise RuntimeError("mps unavailable")
            ranked = rank_predictions(["steady tag", "spike tag"], [0.62, 0.31], limit=2)
            return InferenceBundle(
                summary=build_summary(ranked),
                predictions=[prediction.to_dict() for prediction in ranked],
                highlights=build_highlights(ranked, limit=2),
                timing_ms={"preprocess": 5, "inference": 12, "total": 17},
                warnings=[],
            )

    with patch("reaper_panns_runtime.model_adapter.PannsModelRunner", FakeRunner):
        result = analyze_audio_file(Path("/tmp/item.wav"), Path("/tmp/model.pth"), primary_backend="auto")

    assert result["backend"] == "cpu"
    assert result["attempted_backends"] == ["mps", "cpu"]
    assert result["warnings"][0].startswith("mps inference failed")


def test_rank_predictions_uses_top_k_mean_and_support_counts() -> None:
    predictions = rank_predictions(
        ["spike", "steady"],
        [
            [0.99, 0.60],
            [0.01, 0.62],
            [0.01, 0.61],
            [0.01, 0.59],
        ],
        limit=2,
    )
    assert [row.label for row in predictions] == ["steady", "spike"]
    assert predictions[0].support_count == 4
    assert predictions[1].support_count == 1


def test_rank_predictions_breaks_ties_by_peak_then_label() -> None:
    predictions = rank_predictions(
        ["beta", "alpha"],
        [
            [0.80, 0.70],
            [0.40, 0.50],
            [0.30, 0.30],
        ],
        limit=2,
    )
    assert [row.label for row in predictions] == ["beta", "alpha"]
