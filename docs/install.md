# Installation

## Public macOS install flow

### 1. Install the required host apps

1. Install REAPER `7.x`.
2. Install Python `3.11`.

### 2. Install ReaPack and ReaImGui in REAPER

1. Open REAPER.
2. Check whether `Extensions -> ReaPack -> Browse Packages...` exists.
3. If that menu is missing, install ReaPack first, restart REAPER, and come back to this step.
4. Open `Extensions -> ReaPack -> Browse Packages...`.
5. Search for `ReaImGui: ReaScript binding for Dear ImGui`.
6. Install it.
7. Restart REAPER.

### 3. Download the project ZIP

1. Open the [GitHub Releases page](https://github.com/dennech/reaper-audio-tag/releases/latest).
2. Download the latest ZIP for this project.
3. Unpack it anywhere on your Mac.

You do not need `git clone` for a normal install. Cloning is only for development.

### 4. Set up the PANNs runtime and model

1. Open the unpacked folder.
2. Run `scripts/bootstrap.command`.
3. Wait until it finishes.

`bootstrap.command` is the public entrypoint. Under the hood it calls `scripts/bootstrap_runtime.sh`, but normal users should run `bootstrap.command`.

What this step does automatically:

- creates the managed runtime environment
- installs the packaged Python runtime into the REAPER-managed venv
- downloads the `Cnn14_mAP=0.431.pth` checkpoint
- validates the checkpoint before enabling it
- writes the runtime config into the REAPER user data directory

You do not manually install the PANNs model in the normal flow. The bootstrap step downloads and verifies it for you.

### 5. Add the action in REAPER

1. In REAPER, import `reaper/REAPER Audio Tag.lua` into the Actions list.
2. Select one audio item.
3. Run the script.
4. After a successful run you can keep the window open, select a different item, and click `Another`.

## Developer setup

- Developers can still clone the repository and run `scripts/bootstrap.command` from the checkout.
- If you pull a newer revision later, run `scripts/bootstrap.command` again so the managed runtime picks up the updated package version.

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
