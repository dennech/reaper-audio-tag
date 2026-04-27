# Third-Party Notices

This project includes or packages the following third-party components:

## Noto Emoji image assets

- Source: `googlefonts/noto-emoji`
- Upstream repo: `https://github.com/googlefonts/noto-emoji`
- Pinned commit: `8998f5dd683424a73e2314a8c1f1e359c19e8742`
- Files vendored under `reaper/assets/noto-emoji/png128`
- Generated runtime bundles:
  - `reaper/lib/report_icon_assets.lua`
  - `reaper/lib/report_icon_map.lua`
- License treatment for this project:
  - We bundle PNG image resources, not the font files.
  - The upstream README states that emoji fonts under `fonts/` are `SIL Open Font License 1.1`.
  - The upstream README also states that tools and most image resources are `Apache License 2.0`.
  - For the vendored PNG image resources used by this project, keep `reaper/assets/noto-emoji/LICENSE-APACHE-2.0.txt` with the distribution.
  - The upstream OFL text remains at `reaper/assets/noto-emoji/LICENSE` for reference about the font software and upstream repository layout.

## PANNs / audioset_tagging_cnn

- Source: `qiuqiangkong/audioset_tagging_cnn`
- Upstream repo: `https://github.com/qiuqiangkong/audioset_tagging_cnn`
- Upstream pretrained model archive: `https://zenodo.org/records/3987831`
- Paper: Qiuqiang Kong, Yin Cao, Turab Iqbal, Yuxuan Wang, Wenwu Wang, Mark D. Plumbley, "PANNs: Large-Scale Pretrained Audio Neural Networks for Audio Pattern Recognition"
- The current public backend uses an ONNX export of the upstream `Cnn14_mAP=0.431.pth` checkpoint.
- This project uses the model for clip-level AudioSet tagging and maps the 527 model outputs to human-readable labels.
- License notes:
  - upstream code: MIT
  - Zenodo pretrained model archive: Creative Commons Attribution 4.0 International

## AudioSet class labels

- Source: Google AudioSet class label index CSV
- File vendored under `reaper/data/class_labels_indices.csv`
- Used for mapping class indices to human-readable labels

## ONNX Runtime

- Source: `microsoft/onnxruntime`
- Packaged inside platform backend release binaries.
- macOS uses the CoreML execution provider when available.
- Windows uses the DirectML execution provider when available.
- License: MIT

## NumPy

- Source: `numpy/numpy`
- Packaged inside platform backend release binaries.
- License: BSD-3-Clause

## PyInstaller

- Source: `pyinstaller/pyinstaller`
- Used to build platform backend release binaries.
- License: GPL-2.0-or-later with a bootloader exception

## json.lua

- Source: `rxi/json.lua`
- File vendored under `reaper/lib/json.lua`
- License: MIT

## luaunit

- Source: `bluebird75/luaunit`
- File vendored under `tests/lua/vendor/luaunit.lua`
- License: BSD-style, see upstream repository for the complete text

See the upstream repositories for full license terms and attribution details.
