# Install REAPER Audio Tag

## Recommended Flow

1. Install ReaPack.
2. Import this repository URL:

```text
https://github.com/dennech/reaper-audio-tag/raw/main/index.xml
```

3. Install `REAPER Audio Tag` from ReaPack.
4. Install `ReaImGui: ReaScript binding for Dear ImGui` from ReaPack.
5. Restart REAPER if requested.
6. Select one audio item and run `REAPER Audio Tag`.
7. Click `Download Model`.
8. After the model is ready, run `REAPER Audio Tag` to analyze the selected item.
9. Optional: click `Write Tags to Project` to create/update a region and save the full tag list in the selected item notes.

## What ReaPack Installs

ReaPack installs:

- the Lua action UI;
- the debug export action;
- class label metadata;
- the platform backend executable for your REAPER platform.

The ONNX model is not stored in git. The main action downloads it from the GitHub Release asset when you click `Download Model`.
It is an ONNX export of the upstream PANNs `Cnn14_mAP=0.431.pth` checkpoint.

## Downloaded Model

```text
File: cnn14_waveform_clipwise_opset17.onnx
Size: about 327 MB
SHA-256: deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

Stored under:

```text
REAPER/Data/reaper-panns-item-report/models/
```

No Python, venv, FFmpeg, or manual `.pth` checkpoint setup is required.

For model attribution and maintainer conversion notes, see [model.md](model.md).
