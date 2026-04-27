from __future__ import annotations

import csv
from pathlib import Path


def load_labels(path: str | Path) -> list[str]:
    labels: list[str] = []
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            label = (row.get("display_name") or "").strip()
            if label:
                labels.append(label)
    if not labels:
        raise RuntimeError(f"No labels were loaded from {path}")
    return labels
