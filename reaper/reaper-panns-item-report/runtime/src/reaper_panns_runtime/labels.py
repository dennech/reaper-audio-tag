# @noindex
from __future__ import annotations

import csv
from functools import lru_cache

from .paths import bundled_labels_csv


@lru_cache(maxsize=1)
def load_labels() -> list[str]:
    labels: list[str] = []
    with bundled_labels_csv().open("r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            labels.append(row["display_name"])
    return labels
