from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Callable
from urllib.request import Request, urlopen

from .json_io import write_json


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_file(path: str | Path, *, sha256: str, size: int | None = None) -> tuple[bool, str]:
    target = Path(path)
    if not target.exists():
        return False, "missing"
    if size is not None and target.stat().st_size != size:
        return False, "size_mismatch"
    actual = sha256_file(target)
    if actual.lower() != sha256.lower():
        return False, "checksum_mismatch"
    return True, "ok"


def download_verified(
    *,
    url: str,
    output: str | Path,
    sha256: str,
    size: int | None,
    progress_file: str | Path | None,
    progress_callback: Callable[[int, int | None], None] | None = None,
) -> Path:
    destination = Path(output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    ok, _ = verify_file(destination, sha256=sha256, size=size)
    if ok:
        return destination

    temp_path = destination.with_suffix(destination.suffix + ".download")
    if temp_path.exists():
        temp_path.unlink()

    request = Request(url, headers={"User-Agent": "REAPER-Audio-Tag"})
    with urlopen(request, timeout=30) as response, temp_path.open("wb") as handle:
        total_header = response.headers.get("Content-Length")
        total = int(total_header) if total_header and total_header.isdigit() else size
        downloaded = 0
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            handle.write(chunk)
            downloaded += len(chunk)
            if progress_file:
                write_json(progress_file, {"status": "downloading", "downloaded": downloaded, "total": total or 0})
            if progress_callback:
                progress_callback(downloaded, total)

    ok, reason = verify_file(temp_path, sha256=sha256, size=size)
    if not ok:
        temp_path.unlink(missing_ok=True)
        raise RuntimeError(f"Downloaded model failed verification: {reason}")
    temp_path.replace(destination)
    if progress_file:
        write_json(progress_file, {"status": "done", "downloaded": destination.stat().st_size, "total": size or destination.stat().st_size})
    return destination
