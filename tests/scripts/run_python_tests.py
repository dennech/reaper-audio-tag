#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib
import inspect
import pathlib
import sys
from types import ModuleType


TEST_MODULES = {
    "python": [
        "tests.python.test_audio_fixtures",
        "tests.python.test_bootstrap_model_paths",
        "tests.python.test_contracts",
        "tests.python.test_fake_cli",
        "tests.python.test_runtime_contract",
        "tests.python.test_runtime_cli",
    ],
    "integration": [
        "tests.integration.test_end_to_end",
    ],
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run Python tests with pytest if available, otherwise use a tiny fallback runner.")
    parser.add_argument("--scope", choices=["python", "integration", "all"], default="all")
    return parser


def _repo_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]


def _ensure_sys_path() -> None:
    root_path = _repo_root()
    for candidate in (root_path, root_path / "reaper" / "runtime" / "src"):
        path = str(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)


def _load_modules(scope: str) -> list[ModuleType]:
    module_names: list[str] = []
    if scope == "all":
        module_names = TEST_MODULES["python"] + TEST_MODULES["integration"]
    else:
        module_names = TEST_MODULES[scope]
    return [importlib.import_module(name) for name in module_names]


def _run_fallback(scope: str) -> int:
    _ensure_sys_path()
    failures = 0
    total = 0
    for module in _load_modules(scope):
        for name, function in inspect.getmembers(module, inspect.isfunction):
            if not name.startswith("test_"):
                continue
            total += 1
            try:
                function()
            except Exception as exc:  # pragma: no cover - fallback runner path
                failures += 1
                print(f"FAIL {module.__name__}.{name}: {exc}")
            else:
                print(f"PASS {module.__name__}.{name}")
    print(f"Ran {total} tests, {failures} failed")
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    _ensure_sys_path()

    try:
        import pytest  # type: ignore
    except Exception:
        return _run_fallback(args.scope)

    test_paths = []
    if args.scope in {"python", "all"}:
        test_paths.append("tests/python")
    if args.scope in {"integration", "all"}:
        test_paths.append("tests/integration")
    return int(pytest.main(["-q", *test_paths]))


if __name__ == "__main__":
    raise SystemExit(main())
