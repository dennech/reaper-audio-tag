# Модель И Конвертация

Обычному пользователю REAPER эта страница не нужна. Плагин сам скачивает подготовленную ONNX-модель из GitHub Release, когда пользователь нажимает `Download Model`.

Эта страница фиксирует, какая модель используется, и как maintainer может воспроизвести ONNX-экспорт.

## Исходная Модель

REAPER Audio Tag использует audio tagging модель PANNs `Cnn14` из проекта `qiuqiangkong/audioset_tagging_cnn`.

- Paper: Qiuqiang Kong, Yin Cao, Turab Iqbal, Yuxuan Wang, Wenwu Wang, Mark D. Plumbley, “PANNs: Large-Scale Pretrained Audio Neural Networks for Audio Pattern Recognition”.
- Upstream code: <https://github.com/qiuqiangkong/audioset_tagging_cnn>
- Upstream pretrained models: <https://zenodo.org/records/3987831>
- Исходный checkpoint: `Cnn14_mAP=0.431.pth`
- Задача: clip-level AudioSet tagging.
- Классы: 527 sound classes из AudioSet.
- Лицензии: upstream PANNs code распространяется под MIT; Zenodo archive с pretrained models указан как CC BY 4.0.

Release asset этого проекта — ONNX-экспорт этого checkpoint:

```text
cnn14_waveform_clipwise_opset17.onnx
size 327331996 bytes
sha256 deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

Runtime подаёт в модель mono 32 kHz audio, нарезанное на фиксированные 10-секундные окна: `320000` waveform samples на сегмент.

## Почему ONNX

Оригинальная модель PANNs — это PyTorch checkpoint. REAPER Audio Tag использует небольшой platform backend и ONNX Runtime, чтобы обычному пользователю не нужно было ставить Python, PyTorch или venv.

ONNX-модель не хранится в git, потому что она большая. Она прикрепляется к GitHub Releases и после загрузки проверяется по размеру и SHA-256.

## Повторный Экспорт Модели

Это developer/maintainer workflow. Его нужно запускать вне REAPER.

1. Создай локальную папку эксперимента:

```bash
mkdir -p .local-models/onnx-experiment/checkpoints
mkdir -p .local-models/onnx-experiment/exports
```

2. Склонируй upstream PANNs repository:

```bash
git clone https://github.com/qiuqiangkong/audioset_tagging_cnn .local-models/onnx-experiment/audioset_tagging_cnn
```

3. Скачай upstream checkpoint с Zenodo:

```bash
curl -L \
  "https://zenodo.org/record/3987831/files/Cnn14_mAP%3D0.431.pth?download=1" \
  -o .local-models/onnx-experiment/checkpoints/Cnn14_mAP=0.431.pth
```

4. Создай export environment:

```bash
python3.11 -m venv .local-models/onnx-experiment/export-venv
. .local-models/onnx-experiment/export-venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[model-export]"
```

5. Экспортируй ONNX:

```bash
python scripts/export_cnn14_to_onnx.py \
  --panns-repo .local-models/onnx-experiment/audioset_tagging_cnn \
  --checkpoint .local-models/onnx-experiment/checkpoints/Cnn14_mAP=0.431.pth \
  --output .local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17.onnx
```

6. Если экспорт предназначен для release, проверь и подготовь asset:

```bash
python scripts/prepare_model_asset.py \
  --source .local-models/onnx-experiment/exports/cnn14_waveform_clipwise_opset17.onnx
```

`prepare_model_asset.py` специально проверяет текущие закреплённые размер и checksum release-модели. Если модель меняется намеренно, нужно обновить pinned constants и прогнать сравнение качества/скорости перед публикацией.

## Ожидания По Качеству

Любой новый экспорт модели нужно сравнить с PyTorch checkpoint перед release. Минимум:

- top tags должны оставаться стабильными на synthetic и real audio fixtures;
- checksum и file size должны быть закреплены в Lua и backend constants;
- macOS CoreML, Windows DirectML и CPU fallback должны загружать модель;
- ReaPack install flow должен по-прежнему скачивать и проверять release asset.

Локальные ONNX/CoreML experiment files в `.local-models/onnx-experiment/` специально игнорируются git.
