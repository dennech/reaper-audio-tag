# @noindex
from __future__ import annotations

import hashlib
import os
import shutil
import urllib.request
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ModelSpec:
    name: str
    filename: str
    url: str
    sha256: str
    size_bytes: int


CNN14_MODEL = ModelSpec(
    name="Cnn14",
    filename="Cnn14_mAP=0.431.pth",
    url="https://zenodo.org/api/records/3987831/files/Cnn14_mAP=0.431.pth/content",
    sha256="0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31",
    size_bytes=327428481,
)


def sha256sum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _set_private_file_permissions(path: Path) -> None:
    if os.name == "nt":
        return
    os.chmod(path, 0o600)


def _set_private_dir_permissions(path: Path) -> None:
    if os.name == "nt":
        return
    os.chmod(path, 0o700)


def _ensure_private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _set_private_dir_permissions(path)


def verify_model(path: Path, spec: ModelSpec) -> bool:
    if not path.is_file():
        return False
    if path.stat().st_size != spec.size_bytes:
        return False
    return sha256sum(path) == spec.sha256


def download_model(target_dir: Path, spec: ModelSpec = CNN14_MODEL, force: bool = False) -> Path:
    _ensure_private_dir(target_dir)
    destination = target_dir / spec.filename

    if destination.exists() and verify_model(destination, spec) and not force:
        _set_private_file_permissions(destination)
        return destination

    if destination.exists():
        destination.unlink()

    temp_path = destination.with_suffix(destination.suffix + ".part")
    with urllib.request.urlopen(spec.url, timeout=60) as response, temp_path.open("wb") as handle:
        shutil.copyfileobj(response, handle)

    if not verify_model(temp_path, spec):
        temp_path.unlink(missing_ok=True)
        raise RuntimeError("Downloaded model failed checksum verification.")

    temp_path.replace(destination)
    _set_private_file_permissions(destination)
    return destination


def copy_verified_model(
    source_path: Path,
    destination_path: Path,
    spec: ModelSpec = CNN14_MODEL,
    *,
    force: bool = False,
) -> Path:
    source = Path(source_path).expanduser().resolve(strict=False)
    destination = Path(destination_path).expanduser().resolve(strict=False)

    if not verify_model(source, spec):
        raise RuntimeError(f"Source model failed checksum verification: {source}")

    _ensure_private_dir(destination.parent)

    if destination.exists() and verify_model(destination, spec) and not force:
        _set_private_file_permissions(destination)
        return destination

    if destination.exists():
        destination.unlink()

    temp_path = destination.with_suffix(destination.suffix + ".part")
    temp_path.unlink(missing_ok=True)
    shutil.copyfile(source, temp_path)

    if not verify_model(temp_path, spec):
        temp_path.unlink(missing_ok=True)
        raise RuntimeError(f"Copied model failed checksum verification: {destination}")

    temp_path.replace(destination)
    _set_private_file_permissions(destination)
    return destination
