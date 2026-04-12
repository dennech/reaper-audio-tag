from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


def confidence_bucket(score: float) -> str:
    if score >= 0.7:
        return "strong"
    if score >= 0.4:
        return "solid"
    if score >= 0.18:
        return "possible"
    return "weak"


@dataclass(frozen=True)
class RankedPrediction:
    rank: int
    label: str
    score: float
    bucket: str

    def to_dict(self) -> dict[str, object]:
        return {
            "rank": self.rank,
            "label": self.label,
            "score": round(self.score, 4),
            "bucket": self.bucket,
        }


def rank_predictions(labels: Iterable[str], scores: Iterable[float], *, limit: int = 12) -> list[RankedPrediction]:
    ranked = sorted(zip(labels, scores), key=lambda pair: pair[1], reverse=True)
    result: list[RankedPrediction] = []
    for index, (label, score) in enumerate(ranked[:limit], start=1):
        score_value = float(score)
        result.append(
            RankedPrediction(
                rank=index,
                label=label,
                score=score_value,
                bucket=confidence_bucket(score_value),
            )
        )
    return result


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
                "headline": {
                    "strong": "Strong signal",
                    "solid": "Clear signal",
                    "possible": "Possible match",
                }[prediction.bucket],
            }
        )
        if len(highlights) >= limit:
            break
    return highlights


def build_summary(predictions: list[RankedPrediction]) -> str:
    labels = [prediction.label for prediction in predictions[:3]]
    if not labels:
        return "No confident tags were produced."
    if len(labels) == 1:
        return f"Most likely content: {labels[0]}."
    return "Most likely content: " + ", ".join(labels[:-1]) + f", and {labels[-1]}."

