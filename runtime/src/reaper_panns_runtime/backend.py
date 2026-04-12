from __future__ import annotations

import os
from dataclasses import asdict, dataclass
from typing import Iterable

try:
    import torch
except Exception:  # pragma: no cover - optional dependency for fake/bootstrap-only flows
    torch = None


@dataclass
class ProbeResult:
    status: str
    backend: str
    device: str
    warnings: list[str]
    torch_version: str
    cpu_threads: int

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def cpu_threads() -> int:
    env = os.environ.get("REAPER_PANNS_CPU_THREADS")
    if env:
        try:
            return max(1, int(env))
        except ValueError:
            pass
    return max(1, os.cpu_count() or 1)


def configure_cpu_threads() -> int:
    threads = cpu_threads()
    if torch is not None:
        torch.set_num_threads(threads)
        if hasattr(torch, "set_num_interop_threads"):
            torch.set_num_interop_threads(max(1, min(threads, 4)))
    return threads


def _mps_candidates(requested_backend: str) -> Iterable[str]:
    if requested_backend == "cpu":
        return ["cpu"]
    if requested_backend == "mps":
        return ["mps", "cpu"]
    return ["mps", "cpu"]


def probe_backend(requested_backend: str = "auto") -> ProbeResult:
    warnings: list[str] = []
    threads = configure_cpu_threads()

    if torch is None:
        warnings.append("torch is not installed; acceleration probing was skipped.")
        return ProbeResult("warning", "cpu", "cpu", warnings, "unavailable", threads)

    for backend in _mps_candidates(requested_backend):
        try:
            if backend == "mps":
                if not hasattr(torch.backends, "mps") or not torch.backends.mps.is_built():
                    raise RuntimeError("PyTorch was built without MPS support.")
                if not torch.backends.mps.is_available():
                    raise RuntimeError("MPS is unavailable on this machine.")
                sample = torch.ones((8,), device="mps")
                _ = (sample * 2).cpu().numpy()
                return ProbeResult("ok", "mps", "mps", warnings, torch.__version__, threads)

            sample = torch.ones((8,), device="cpu")
            _ = (sample * 2).numpy()
            return ProbeResult("ok", "cpu", "cpu", warnings, torch.__version__, threads)
        except Exception as exc:  # pragma: no cover - defensive fallback
            warnings.append(f"{backend} probe failed: {exc}")

    return ProbeResult("error", "cpu", "cpu", warnings, torch.__version__, threads)
