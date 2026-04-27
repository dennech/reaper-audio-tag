from __future__ import annotations

import hashlib
import socket
import ssl
from pathlib import Path
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

import certifi

from .json_io import write_json


class DownloadModelError(RuntimeError):
    def __init__(self, code: str, user_message: str, detail: str | None = None):
        super().__init__(detail or user_message)
        self.code = code
        self.user_message = user_message
        self.detail = detail or user_message


def https_ssl_context(url: str):
    if urlparse(url).scheme.lower() != "https":
        return None
    return ssl.create_default_context(cafile=certifi.where())


def _is_certificate_error(exc: BaseException) -> bool:
    reason = getattr(exc, "reason", None)
    candidates = [exc, reason]
    for candidate in candidates:
        if isinstance(candidate, ssl.SSLCertVerificationError):
            return True
    return "CERTIFICATE_VERIFY_FAILED" in str(exc)


def friendly_download_error(exc: BaseException) -> DownloadModelError:
    if isinstance(exc, DownloadModelError):
        return exc
    if _is_certificate_error(exc):
        return DownloadModelError(
            "certificate_failed",
            "Could not verify GitHub's HTTPS certificate. Update REAPER Audio Tag and try again.",
            str(exc),
        )
    if isinstance(exc, HTTPError):
        return DownloadModelError(
            "http_failed",
            f"Download failed because GitHub returned HTTP {exc.code}. Try again later.",
            str(exc),
        )
    if isinstance(exc, (URLError, TimeoutError, socket.timeout, OSError)):
        return DownloadModelError(
            "network_failed",
            "Download failed. Check your internet connection and try again.",
            str(exc),
        )
    return DownloadModelError("download_failed", "Download failed. Try again.", str(exc))


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
    open_kwargs = {"timeout": 30}
    context = https_ssl_context(url)
    if context is not None:
        open_kwargs["context"] = context
    try:
        with urlopen(request, **open_kwargs) as response, temp_path.open("wb") as handle:
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
    except Exception as exc:
        temp_path.unlink(missing_ok=True)
        raise friendly_download_error(exc) from exc

    ok, reason = verify_file(temp_path, sha256=sha256, size=size)
    if not ok:
        temp_path.unlink(missing_ok=True)
        raise DownloadModelError(
            "verification_failed",
            "The download was incomplete or corrupted. Try downloading again.",
            f"Downloaded model failed verification: {reason}",
        )
    temp_path.replace(destination)
    if progress_file:
        write_json(progress_file, {"status": "done", "downloaded": destination.stat().st_size, "total": size or destination.stat().st_size})
    return destination
