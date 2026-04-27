# REAPER Audio Tag

`REAPER Audio Tag` is a small REAPER action for fast clip-level audio inspection. Select one audio item, run the action, and get compact local `PANNs Cnn14` tags inside REAPER.

Install it with ReaPack, download the ONNX model from inside the REAPER window once, then analyze audio locally without installing Python or leaving your DAW.

![REAPER Audio Tag report window](docs/images/reaper-audio-tag-hero.png)

_Current REAPER Audio Tag report window with top cues, tag chips, timing, and CPU/GPU status._

## What You Need

- REAPER with ReaPack.
- ReaImGui from ReaPack.
- This repository imported as a custom ReaPack repository.

You do not install Python, create a venv, or choose a model file manually. The plugin uses a self-contained backend installed by ReaPack. The ONNX model is downloaded explicitly on first run and stored in REAPER's data folder.

The model is large: about 327 MB.

## Install

1. Install [ReaPack](https://reapack.com/).
2. In REAPER, open `Extensions -> ReaPack -> Import repositories`.
3. Add this repository URL:

```text
https://github.com/dennech/reaper-audio-tag/raw/main/index.xml
```

4. Open `Extensions -> ReaPack -> Browse packages`.
5. Install `REAPER Audio Tag`.
6. Install `ReaImGui: ReaScript binding for Dear ImGui` if it is not already installed.
7. Restart REAPER if ReaPack asks you to.

## First Run

1. Select exactly one audio item.
2. Run `REAPER Audio Tag`.
3. Click `Download Model`.
4. Wait for the download and checksum verification to finish.
5. Run `REAPER Audio Tag` again, or click `Analyze Selected Item` if the window is still open.

The model is downloaded from this project's GitHub Release assets:

```text
cnn14_waveform_clipwise_opset17.onnx
sha256 deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

The model is stored here:

```text
REAPER/Data/reaper-panns-item-report/models/
```

## Platforms

- macOS Apple Silicon and Intel: CoreML is tried first, then CPU fallback.
- Windows x64: DirectML is tried first, then CPU fallback.
- If GPU acceleration is unavailable, analysis still runs on CPU.

The first CoreML run on macOS can be slower because macOS compiles and caches the model.

## Public Actions

- `REAPER Audio Tag`
- `REAPER Audio Tag - Debug Export`

There is no separate setup or configure action in the public package.

## Notes

- FFmpeg is not required for the current public flow.
- Analysis is local after the model has been downloaded.
- The current version analyzes one selected audio item at a time and produces clip-level tags.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).
