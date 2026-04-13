# Installation

## macOS v1 flow

1. Install REAPER `7.x`.
2. Install `ReaImGui` in REAPER via ReaPack.
3. Install Python `3.11`.
4. Clone this repository locally.
5. Run `scripts/bootstrap.command`.
6. Wait until the script:
   - creates the local runtime environment
   - installs the packaged Python runtime into the managed REAPER venv
   - downloads the `Cnn14_mAP=0.431.pth` checkpoint
   - validates the checkpoint with a strong checksum before enabling the runtime
   - writes the runtime config into the REAPER user data directory
7. In REAPER, import `reaper/REAPER Audio Tag.lua` into the Actions list.
8. Select one audio item and run the script.
9. After a successful run you can keep the window open, select a different item, and click `Another`.

If you downloaded the public source release from GitHub, you can unpack it anywhere and run `scripts/bootstrap.command` directly. Cloning is only required for development.
If you pull a newer revision of the repository later, run `scripts/bootstrap.command` once again so the managed runtime inside REAPER picks up the new package version.

## Where the runtime stores data

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Preferred model cache: `<repo>/.local-models`
- Fallback model cache: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- Export temp WAVs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- Export logs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

## Notes

- The repository itself stays light: the large model file is cached locally outside Git and `.local-models/` is ignored.
- The script runs only the managed runtime inside `Data/reaper-panns-item-report/runtime/venv`.
- Audio is downmixed to mono and resampled to `32 kHz` before tagging.
- The report is clip-level tagging, not event detection.
- Temporary export WAVs and finished run artifacts are cleaned up automatically. The original source media is never deleted.
- If `ReaImGui` is missing, the script shows an install hint instead of crashing.
- The compact UI uses bundled Noto Emoji PNG assets, so it no longer depends on system emoji rendering.
- The pinned upstream source for those assets is documented under `reaper/assets/noto-emoji/README.md`.
- If the image path is unavailable in a specific REAPER session, the UI falls back to plain text labels instead of blank boxes.
- Windows is intentionally out of scope for v1.
