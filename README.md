# REAPER Audio Tag

`REAPER Audio Tag` is a REAPER action for quick clip-level audio inspection.

<img src="docs/images/reaper-audio-tag-hero.png" alt="REAPER Audio Tag report window" width="760">

_Current REAPER Audio Tag report window on macOS._

## Status

- macOS only
- Apple Silicon and Intel Mac are supported
- Windows is not available yet
- One selected audio item at a time
- Clipwise audio tagging only
- `ReaImGui` is required

## What This Package Includes

The ReaPack package includes:

- the Lua actions and UI
- the project's local Python runtime source code

The ReaPack package does **not** include:

- Python itself
- third-party Python packages such as `torch`
- the PANNs model file

This is intentional. The setup is meant to stay transparent and inspectable.

## What It Does

1. Exports the exact selected take region from REAPER.
2. Downmixes the audio to mono.
3. Resamples it to `32 kHz`.
4. Runs local `PANNs Cnn14` tagging.
5. Shows a compact report inside REAPER.

This is a practical clip-level inspection tool. It is **not** a timeline event detector.

## Privacy and Trust

- Audio stays on your machine.
- No cloud processing.
- No hidden installer inside REAPER.
- No automatic Python download from REAPER.
- No automatic model download from REAPER.
- You choose the Python path.
- You choose the model path.
- The script validates those paths before analysis starts.

## Requirements

- REAPER `7.x`
- `ReaPack`
- `ReaImGui`
- macOS Apple Silicon or Intel Mac
- Python `3.11`
- Enough disk space for the Python environment and the model file

## Manual Install Notes

- macOS only for now
- This project currently uses its own custom ReaPack repository URL
- REAPER does not install Python or download the model for you
- The required model file `Cnn14_mAP=0.431.pth` is large, about `327 MB`
- v1 is intentionally conservative: one selected audio item at a time, local inference only, clipwise tagging only

## Installation

### 1. Install the package with ReaPack

For now, installation uses this project's own ReaPack repository.

1. Install REAPER `7.x`.
2. If `ReaPack` is not installed yet, install it from [reapack.com](https://reapack.com/).
3. In REAPER, open `Extensions -> ReaPack -> Import repositories...`.
4. Add this repository URL:

```text
https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml
```

5. Open `Extensions -> ReaPack -> Browse Packages...`.
6. Search for `REAPER Audio Tag`.
7. Install the package.

### 2. Install ReaImGui

1. In ReaPack, search for `ReaImGui: ReaScript binding for Dear ImGui`.
2. Install it.
3. Restart REAPER.

### 3. Install Python 3.11

Install Python `3.11` from a source you trust.

Recommended: use the official installer from python.org.

After installation, confirm it is available in Terminal:

```bash
python3.11 --version
```

### 4. Create a local Python environment and install dependencies

This project expects a local Python environment with the required dependencies already installed.

Recommended location:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv
```

Create the environment:

```bash
mkdir -p "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report"
python3.11 -m venv "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv"
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install --upgrade pip
```

Install the required Python packages:

```bash
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

The Python path you will use later in REAPER is:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python
```

Optional helper script for source checkouts or manual repository downloads:

```bash
./scripts/create_local_venv_macos.sh
```

That helper stays fully optional. It only creates the venv, installs the pinned dependencies, and prints the Python path to paste into `Configure`.

### 5. Download the model manually

Download this file yourself:

- file name: `Cnn14_mAP=0.431.pth`
- expected SHA-256: `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`
- size: about `327 MB`

Recommended source:

- Zenodo: [Cnn14_mAP=0.431.pth](https://zenodo.org/records/3987831/files/Cnn14_mAP%3D0.431.pth)

Keep the original file name.

Verify the checksum before using it:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

Expected result:

```text
0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31
```

### 6. Configure the paths inside REAPER

Open the Action List and run:

```text
REAPER Audio Tag: Configure
```

Set:

- **Python executable**: the executable file inside your environment, usually `.../venv/bin/python`
- **Model file**: the downloaded file `Cnn14_mAP=0.431.pth`

Examples:

- preferred Python path: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
- acceptable Homebrew path: `/opt/homebrew/bin/python3.11`
- model path: `/path/to/Cnn14_mAP=0.431.pth`

Then use:

- `Validate`
- `Save`

<!-- TODO: Replace this placeholder reference with a real Configure screenshot before the next release. -->
![REAPER Audio Tag Configure window](docs/images/reaper-audio-tag-configure.png)

_Suggested Configure screen: Python path, model path, validation state, and save action._

### 7. Run the report

1. Select exactly one audio item.
2. Run:

```text
REAPER Audio Tag
```

If the configuration is missing or invalid, the script opens `Configure` instead of trying to run analysis.

## First-Run Notes

- The first analysis run can take longer because Python packages and the model need to load.
- On Apple Silicon, the backend may use `MPS` with `CPU` fallback.
- On Intel Macs, analysis runs on `CPU`.
- v1 is intentionally conservative: reliability first.

## External Tools

`FFmpeg` is **not required** for the current version.

Audio is exported from REAPER directly by the script, so there is no separate `ffmpeg` install step in the normal flow.

## Where Things Are Stored

Recommended layout:

- REAPER-side config and temp data:
  - `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`
- Python environment:
  - `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/`
- Model file:
  - anywhere you prefer, as long as `Configure` points to it

The REAPER package stores only its own config, logs, jobs, and temp files under the REAPER data directory.

## Troubleshooting

### ReaImGui is missing

Install `ReaImGui: ReaScript binding for Dear ImGui` from ReaPack and restart REAPER.

### Python path is invalid

Make sure `Configure` points to the Python executable file inside your local environment, not to a folder or a random system path.

Good examples:

- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
- `/opt/homebrew/bin/python3.11`
- `/usr/local/bin/python3.11`

The long `Cellar/.../Python.framework/...` path can work, but the local venv path is preferred.

### Python dependencies are missing

Activate the same environment and reinstall the required packages:

```bash
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

### `Configure` says the shipped runtime source is missing

- Open `Extensions -> ReaPack -> Synchronize packages`.
- Update `REAPER Audio Tag` to the latest version.
- Reopen `REAPER Audio Tag: Configure`.
- If the installed package still has only `reaper/...` files but no `reaper/runtime/src/...`, reinstall the package from this repo's ReaPack URL.

### The model file is rejected

Check all of the following:

- the file name is exactly `Cnn14_mAP=0.431.pth`
- the download is complete
- the SHA-256 checksum matches

### The first run is slow

That is expected. Loading `torch` and the model can take noticeable time on the first run.

## Uninstall

To remove the project completely:

1. Remove the package from ReaPack.
2. Delete the project data folder if you no longer need it:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/
```

3. Delete the model file if you no longer want to keep it.

## Development

Developer and source-checkout workflows can stay documented separately.

Public users should not need to clone the repository just to use the script.

## Notes

- The project vendors the official PANNs model code needed for `Cnn14` loading.
- Export preparation runs incrementally on the Lua side before Python inference starts, so opening the report stays responsive on longer selected items.
- The script cleans up only its own temporary export WAVs, job files, and logs inside `Data/reaper-panns-item-report/{tmp,jobs,logs}`. It never deletes the original source audio or project media.
- The compact report uses bundled Noto Emoji PNG assets instead of system text emoji, so tag chips stay consistent across REAPER and ReaImGui setups.
- A broader public ReaPack distribution channel may be evaluated later. For now, the project uses its own repository URL directly.

## License

MIT
