from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

APP_SLUG = "reaper-panns-item-report"
PRIVATE_DIR_MODE = 0o700


@dataclass(frozen=True)
class RuntimePaths:
    resource_dir: Path
    data_dir: Path
    runtime_dir: Path
    jobs_dir: Path
    logs_dir: Path
    tmp_dir: Path
    models_dir: Path
    config_path: Path
    last_probe_path: Path
    venv_dir: Path
    repo_root: Path


def detect_reaper_resource_dir() -> Path:
    override = os.environ.get("REAPER_RESOURCE_PATH")
    if override:
        return Path(override).expanduser().resolve()

    home = Path.home()
    if sys.platform == "darwin":
        return (home / "Library" / "Application Support" / "REAPER").resolve()
    if sys.platform.startswith("win"):
        appdata = os.environ.get("APPDATA")
        if appdata:
            return (Path(appdata) / "REAPER").resolve()
        return (home / "AppData" / "Roaming" / "REAPER").resolve()
    return (home / ".config" / "REAPER").resolve()


def repo_root() -> Path:
    override = os.environ.get("REAPER_PANNS_REPO_ROOT")
    if override:
        return Path(override).expanduser().resolve()
    return Path(__file__).resolve().parents[3]


def package_root() -> Path:
    return Path(__file__).resolve().parent


def bundled_labels_csv() -> Path:
    return package_root() / "_vendor" / "metadata" / "class_labels_indices.csv"


def default_paths() -> RuntimePaths:
    resource_dir = detect_reaper_resource_dir()
    data_dir = resource_dir / "Data" / APP_SLUG
    runtime_dir = data_dir / "runtime"
    return RuntimePaths(
        resource_dir=resource_dir,
        data_dir=data_dir,
        runtime_dir=runtime_dir,
        jobs_dir=data_dir / "jobs",
        logs_dir=data_dir / "logs",
        tmp_dir=data_dir / "tmp",
        models_dir=data_dir / "models",
        config_path=data_dir / "config.json",
        last_probe_path=data_dir / "last_probe.json",
        venv_dir=runtime_dir / "venv",
        repo_root=repo_root(),
    )


def ensure_directories(paths: RuntimePaths) -> None:
    for directory in (
        paths.data_dir,
        paths.runtime_dir,
        paths.jobs_dir,
        paths.logs_dir,
        paths.tmp_dir,
        paths.models_dir,
        paths.venv_dir,
    ):
        directory.mkdir(parents=True, exist_ok=True)
        if os.name != "nt":
            directory.chmod(PRIVATE_DIR_MODE)
