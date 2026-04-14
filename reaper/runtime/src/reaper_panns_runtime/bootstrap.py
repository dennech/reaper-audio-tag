# @noindex
from __future__ import annotations

from pathlib import Path
from typing import Any

from .backend import probe_backend
from .config_store import default_config, load_config, save_config
from .contract import write_json
from .downloader import CNN14_MODEL, copy_verified_model, download_model, verify_model
from .paths import RuntimePaths, ensure_directories, is_subpath, normalize_path, project_models_dir, project_models_dir_available


def _configured_model_path(paths: RuntimePaths) -> Path | None:
    try:
        config = load_config(paths)
    except Exception:
        return None

    model = config.get("model")
    if not isinstance(model, dict):
        return None
    raw_path = model.get("path")
    if not isinstance(raw_path, str) or not raw_path.strip():
        return None
    return Path(raw_path).expanduser()


def _same_path(left: Path, right: Path) -> bool:
    return normalize_path(left) == normalize_path(right)


def _copy_or_download_project_model(paths: RuntimePaths, spec, configured_path: Path | None, force_download: bool) -> Path:
    target_dir = project_models_dir(paths)
    target_path = target_dir / spec.filename

    if force_download:
        return download_model(target_dir, spec, force=True)

    if verify_model(target_path, spec):
        return target_path

    legacy_path = paths.models_dir / spec.filename
    for source in (configured_path, legacy_path):
        if source is None:
            continue
        if _same_path(source, target_path):
            continue
        if verify_model(source, spec):
            return copy_verified_model(source, target_path, spec)

    return download_model(target_dir, spec, force=False)


def resolve_model_path(paths: RuntimePaths, *, force_download: bool = False):
    spec = CNN14_MODEL
    configured_path = _configured_model_path(paths)

    if project_models_dir_available(paths):
        return _copy_or_download_project_model(paths, spec, configured_path, force_download)

    project_dir = project_models_dir(paths)
    if (
        configured_path is not None
        and not is_subpath(configured_path, project_dir)
        and verify_model(configured_path, spec)
        and not force_download
    ):
        return configured_path

    return download_model(paths.models_dir, spec, force=force_download)


def bootstrap_runtime(paths: RuntimePaths, *, preferred_backend: str = "auto", force_download: bool = False) -> dict[str, Any]:
    ensure_directories(paths)
    model_path = resolve_model_path(paths, force_download=force_download)
    probe = probe_backend(preferred_backend)
    config = default_config(paths, model_path=model_path, preferred_backend=probe.backend, cpu_threads=probe.cpu_threads)
    save_config(paths, config)
    write_json(paths.last_probe_path, {"schema_version": config["schema_version"], "probe": probe.to_dict()})
    return {
        "status": "ok",
        "config_path": str(paths.config_path),
        "model_path": str(model_path),
        "probe": probe.to_dict(),
    }
