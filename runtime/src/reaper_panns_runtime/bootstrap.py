from __future__ import annotations

from typing import Any

from .backend import probe_backend
from .config_store import default_config, save_config
from .contract import write_json
from .downloader import CNN14_MODEL, download_model
from .paths import RuntimePaths, ensure_directories


def bootstrap_runtime(paths: RuntimePaths, *, preferred_backend: str = "auto", force_download: bool = False) -> dict[str, Any]:
    ensure_directories(paths)
    model_path = download_model(paths.models_dir, CNN14_MODEL, force=force_download)
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

