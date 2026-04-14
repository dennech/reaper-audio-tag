# Troubleshooting

## `ReaImGui` is missing

- Open `Extensions -> ReaPack -> Browse Packages...`.
- Search for `ReaImGui: ReaScript binding for Dear ImGui`.
- Install it and restart REAPER.

## `REAPER Audio Tag: Configure` is missing from the Actions list

- Confirm that the `REAPER Audio Tag` package is installed through this repo's ReaPack URL.
- If needed, re-import:

  `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

- Reinstall the package from ReaPack and rescan the Actions list.

## `Configure` says Python 3.11 was not found

- Verify the path in Terminal:

```bash
"/path/to/python" --version
```

- Use the Python executable file inside your local venv, not a folder and not a random system binary.
- Good examples:
  `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
  `/opt/homebrew/bin/python3.11`
  `/usr/local/bin/python3.11`
- The long `Cellar/.../Python.framework/...` path can work, but the local venv path is preferred.
- If needed, recreate the venv with `python3.11 -m venv ...`.

## `Configure` says dependencies are missing

- Activate the same environment that you selected in `Configure`.
- Reinstall the pinned dependencies:

```bash
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

## `Configure` rejects the model file

- Confirm the file name is exactly `Cnn14_mAP=0.431.pth`.
- Choose the file itself, not the folder that contains it.
- Confirm the checksum:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

- Expected value:

  `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`

## The main action keeps opening `Configure`

- Save a new configuration from `REAPER Audio Tag: Configure`.
- Make sure the Python path still exists and is executable.
- Make sure the model file still exists at the saved location.
- If you previously used the bundled-runtime flow, resave the config in the new transparent format.

## `Configure` says the shipped runtime source is missing

- Open `Extensions -> ReaPack -> Synchronize packages`.
- Update `REAPER Audio Tag` to the latest version from this repo's ReaPack URL.
- Reopen `REAPER Audio Tag: Configure`.
- If the installed package still has only `reaper/...` files but no `reaper/runtime/src/...`, reinstall the package from ReaPack.

## The first run is slow

- That is expected on the first run.
- `torch` import and model loading can take noticeable time.

## Where the project stores its own data

- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

## Developer note

- Source checkouts can use a local venv and `scripts/create_local_venv_macos.sh`.
- That is not part of the normal public install flow.
