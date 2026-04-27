# Model and Conversion Notes

Normal REAPER users do not need this page. The plugin downloads the prepared ONNX model from the project release when `Download Model` is clicked.

This page documents which model is used and how maintainers can reproduce the ONNX export.

## Source Model

REAPER Audio Tag uses the PANNs `Cnn14` audio tagging model from `qiuqiangkong/audioset_tagging_cnn`.

- Paper: Qiuqiang Kong, Yin Cao, Turab Iqbal, Yuxuan Wang, Wenwu Wang, Mark D. Plumbley, “PANNs: Large-Scale Pretrained Audio Neural Networks for Audio Pattern Recognition”.
- Upstream code: <https://github.com/qiuqiangkong/audioset_tagging_cnn>
- Upstream pretrained models: <https://zenodo.org/records/3987831>
- Source checkpoint: `Cnn14_mAP=0.431.pth`
- Task: clip-level AudioSet tagging.
- Classes: 527 AudioSet sound classes.
- License notes: upstream PANNs code is MIT licensed; the Zenodo pretrained model archive is listed as CC BY 4.0.

The project release asset is an ONNX export of that checkpoint:

```text
cnn14_waveform_clipwise_opset17.onnx
size 327331996 bytes
sha256 deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

The runtime feeds mono 32 kHz audio into fixed 10-second windows, using `320000` waveform samples per segment.

## Why ONNX

The original PANNs model is a PyTorch checkpoint. REAPER Audio Tag ships a small platform backend and uses ONNX Runtime so normal users do not need Python, PyTorch, or a virtual environment.

The ONNX model is not committed to git because it is large. It is attached to GitHub Releases and verified by file size and SHA-256 after download.

## Re-exporting the Model

This is a developer/maintainer workflow. It should be done outside REAPER.

1. Create a local experiment folder:

```bash
mkdir -p .local-models/onnx-experiment/checkpoints
mkdir -p .local-models/onnx-experiment/exports
```

2. Clone the upstream PANNs repository:

```bash
git clone https://github.com/qiuqiangkong/audioset_tagging_cnn .local-models/onnx-experiment/audioset_tagging_cnn
```

3. Download the upstream checkpoint from Zenodo:

```bash
curl -L \
  "https://zenodo.org/record/3987831/files/Cnn14_mAP%3D0.431.pth?download=1" \
  -o .local-models/onnx-experiment/checkpoints/Cnn14_mAP=0.431.pth
```

4. Create an export environment:

```bash
python3.11 -m venv .local-models/onnx-experiment/export-venv
. .local-models/onnx-experiment/export-venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[model-export]"
```

5. Export ONNX:

```bash
python scripts/export_cnn14_to_onnx.py \
  --panns-repo .local-models/onnx-experiment/audioset_tagging_cnn \
  --checkpoint .local-models/onnx-experiment/checkpoints/Cnn14_mAP=0.431.pth \
  --output .local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17.onnx
```

6. If the exported model is intended for a release, verify and stage it:

```bash
python scripts/prepare_model_asset.py \
  --source .local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17.onnx
```

`prepare_model_asset.py` intentionally checks the currently pinned release model size and checksum. If the model is intentionally changed, update the pinned constants and run quality/speed comparisons before publishing.

## Quality Expectations

Any new model export should be compared against the PyTorch checkpoint before release. At minimum, verify:

- top tags stay consistent on synthetic and real audio fixtures;
- checksum and file size are pinned in both Lua and backend constants;
- macOS CoreML, Windows DirectML, and CPU fallback still load the model;
- the ReaPack install flow still downloads and verifies the release asset.

The local ONNX/CoreML experiment files under `.local-models/onnx-experiment/` are intentionally ignored by git.
