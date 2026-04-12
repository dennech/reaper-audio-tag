# Installation

## macOS v1 flow

1. Install REAPER `7.x`.
2. Install `ReaImGui` in REAPER via ReaPack.
3. Install Python `3.11`.
4. Clone this repository locally.
5. Run `scripts/bootstrap.command`.
6. Wait until the script:
   - creates the local runtime environment
   - installs Python dependencies
   - downloads the `Cnn14_mAP=0.431.pth` checkpoint
   - validates the checkpoint with a strong checksum before enabling the runtime
   - writes the runtime config into the REAPER user data directory
7. In REAPER, import `reaper/PANNs Item Report.lua` into the Actions list.
8. Select one audio item and run the script.

## Where the runtime stores data

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Model: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs and logs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`

## Notes

- The repository itself stays light: the large model file is downloaded outside Git.
- The script runs only the managed runtime inside `Data/reaper-panns-item-report/runtime/venv`.
- If `ReaImGui` is missing, the script shows an install hint instead of crashing.
- Windows is intentionally out of scope for v1.
