# Security Best Practices Report

## Executive Summary

Scope: review and remediation of the REAPER Lua bridge, Python runtime, bootstrap flow, repository contents, and published GitHub state for `reaper-panns-audio-report`.

Current status:

- No committed secrets were found in the repository.
- No personal absolute user-home paths remain in the tracked working tree.
- The original security findings identified during the audit were remediated in the current code.
- The published branch history is intended to be rewritten as part of this remediation so that accidentally committed local paths are removed from accessible Git history.

Threat model:

- Local desktop REAPER plugin, not an internet-exposed service.
- Malicious local scripts, tampered config/model files, and shared-machine privacy risks are in scope.

## Remediated Findings

### SEC-001: PyTorch dependency and checkpoint loading hardening

Status: remediated

Changes applied:

- Upgraded runtime dependencies from `torch==2.2.2` / `torchaudio==2.2.2` to `2.6.0`.
- Switched checkpoint loading to `torch.load(..., weights_only=True)` on the patched runtime line.
- Replaced MD5-only verification with SHA-256 verification for the downloaded checkpoint.

Why this matters:

- GitHub advisory `GHSA-53q9-r3pm-6pq6` marks PyTorch versions earlier than `2.6.0` as affected.
- The new runtime aligns the code with the patched dependency line and a stronger integrity check.

### SEC-002: Mutable config file no longer controls the Python executable

Status: remediated

Changes applied:

- Removed `python_executable` from the managed runtime config written by bootstrap.
- Lua launcher now executes only the managed interpreter located in the deterministic REAPER runtime path.
- Request payloads no longer include a working `model_path` override, and runtime analysis ignores request-side attempts to override the managed model path.

Why this matters:

- A writable local config file is no longer an authority for code execution.
- The action now trusts only the managed runtime created by bootstrap.

### SEC-003: Runtime privacy hardening for local artifacts

Status: remediated

Changes applied:

- Bootstrap now uses `umask 077`.
- Runtime directories are normalized to owner-only permissions on POSIX.
- Managed files such as config JSON, probe JSON, and model checkpoint are written with owner-only file permissions on POSIX.
- Item export metadata no longer includes the original source media path, and the UI/runtime report no longer exposes the full checkpoint path.

Why this matters:

- Shared-machine leakage risk is reduced substantially.
- The current runtime layout on macOS uses `0700` directories and `0600` files for the managed app data checked during validation.

## Verification Performed

- Python and integration test suites passed locally.
- Lua test suite passed locally, including a regression test that verifies the launcher ignores `config.json` executable overrides and omits `model_path` from the request payload.
- Real bootstrap completed successfully on this machine with:
  - `torch 2.6.0`
  - `torchaudio 2.6.0`
  - backend probe result `mps`
- Real `analyze` completed successfully on a short synthetic fixture.
- Runtime permissions on this machine were verified as owner-only for:
  - app data directory
  - runtime directory
  - venv directory
  - models directory
  - jobs/logs/tmp directories
  - config file
  - model checkpoint

## Residual Notes

- The GitHub owner login remains part of the repository URL and owner field because the project stays under the current account. That is a hosting-level identity detail, not a repository content leak.
- The managed config still stores the model path locally because the runtime needs it, but it is protected by owner-only permissions and is not published in repository files or UI output.
- No direct shell-injection issue was identified in the current launcher command construction; shell quoting is preserved.

## External References

- PyTorch security policy: <https://github.com/pytorch/pytorch/security/policy>
- GitHub advisory for PyTorch RCE affecting `< 2.6.0`: <https://github.com/advisories/GHSA-53q9-r3pm-6pq6>
- GitHub advisory for older PyTorch use-after-free issue: <https://github.com/advisories/GHSA-pg7h-5qx3-wjr3>
