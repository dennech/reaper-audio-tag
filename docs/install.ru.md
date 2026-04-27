# Установка REAPER Audio Tag

## Рекомендуемый Путь

1. Установи ReaPack.
2. Импортируй URL этого репозитория:

```text
https://github.com/dennech/reaper-audio-tag/raw/main/index.xml
```

3. Установи `REAPER Audio Tag` через ReaPack.
4. Установи `ReaImGui: ReaScript binding for Dear ImGui` через ReaPack.
5. Перезапусти REAPER, если он попросит.
6. Выбери один audio item и запусти `REAPER Audio Tag`.
7. Нажми `Download Model`.
8. Когда модель будет готова, снова запусти `REAPER Audio Tag` для анализа выбранного item.

## Что Ставит ReaPack

ReaPack устанавливает:

- Lua UI action;
- debug export action;
- metadata с названиями классов;
- backend executable для твоей платформы REAPER.

ONNX-модель не хранится в git. Main action скачивает её из GitHub Release asset, когда ты нажимаешь `Download Model`.

## Скачиваемая Модель

```text
File: cnn14_waveform_clipwise_opset17.onnx
Size: about 327 MB
SHA-256: deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

Сохраняется сюда:

```text
REAPER/Data/reaper-panns-item-report/models/
```

Python, venv, FFmpeg и ручная настройка `.pth` checkpoint больше не нужны.
