from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import numpy as np

from .constants import POSSIBLE_THRESHOLD, TOP_K_SEGMENTS


def confidence_bucket(score: float) -> str:
    if score >= 0.7:
        return "strong"
    if score >= 0.4:
        return "solid"
    if score >= POSSIBLE_THRESHOLD:
        return "possible"
    return "weak"


@dataclass(frozen=True)
class RankedPrediction:
    rank: int
    label: str
    score: float
    bucket: str
    peak_score: float
    support_count: int
    segment_count: int

    def to_dict(self) -> dict[str, object]:
        return {
            "rank": self.rank,
            "label": self.label,
            "score": round(self.score, 4),
            "bucket": self.bucket,
            "peak_score": round(self.peak_score, 4),
            "support_count": self.support_count,
            "segment_count": self.segment_count,
        }


def rank_predictions(labels: Iterable[str], scores: Iterable[float] | np.ndarray, *, limit: int = 12) -> list[RankedPrediction]:
    label_rows = list(labels)
    score_matrix = np.asarray(scores, dtype=np.float32)
    if score_matrix.ndim == 1:
        score_matrix = score_matrix[np.newaxis, :]
    if score_matrix.ndim != 2:
        raise ValueError("scores must be a 1D or 2D array-like value.")
    if score_matrix.shape[1] != len(label_rows):
        raise ValueError("label count and score columns must match.")

    ranked: list[RankedPrediction] = []
    segment_count = int(score_matrix.shape[0])
    top_k = min(TOP_K_SEGMENTS, segment_count)
    for label, column in zip(label_rows, score_matrix.T):
        sorted_scores = np.sort(column)[::-1]
        aggregate_score = float(sorted_scores[:top_k].mean()) if top_k else 0.0
        peak_score = float(sorted_scores[0]) if sorted_scores.size else 0.0
        support_count = int(np.count_nonzero(column >= POSSIBLE_THRESHOLD))
        ranked.append(RankedPrediction(0, label, aggregate_score, confidence_bucket(aggregate_score), peak_score, support_count, segment_count))

    ranked.sort(key=lambda row: (-row.score, -row.peak_score, row.label.lower()))
    return [
        RankedPrediction(index, row.label, row.score, row.bucket, row.peak_score, row.support_count, row.segment_count)
        for index, row in enumerate(ranked[:limit], start=1)
    ]


def build_highlights(predictions: list[RankedPrediction], *, limit: int = 5) -> list[dict[str, object]]:
    highlights: list[dict[str, object]] = []
    for prediction in predictions:
        if prediction.bucket == "weak":
            continue
        highlights.append(
            {
                "label": prediction.label,
                "score": round(prediction.score, 4),
                "bucket": prediction.bucket,
                "peak_score": round(prediction.peak_score, 4),
                "support_count": prediction.support_count,
                "segment_count": prediction.segment_count,
                "headline": {
                    "strong": "Likely tag",
                    "solid": "Consistent tag",
                    "possible": "Possible cue",
                }[prediction.bucket],
            }
        )
        if len(highlights) >= limit:
            break
    return highlights


def build_summary(predictions: list[RankedPrediction]) -> str:
    labels = [prediction.label for prediction in predictions if prediction.bucket != "weak"][:3]
    if not labels:
        labels = [prediction.label for prediction in predictions[:3]]
    if not labels:
        return "No confident tags were produced."
    if len(labels) == 1:
        return f"Top detected tag: {labels[0]}."
    if len(labels) == 2:
        return f"Top detected tags: {labels[0]} and {labels[1]}."
    return "Top detected tags: " + ", ".join(labels[:-1]) + f", and {labels[-1]}."
