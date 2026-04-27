# Troubleshooting

## Не Установлен ReaImGui

Установи `ReaImGui: ReaScript binding for Dear ImGui` через ReaPack и перезапусти REAPER.

## Backend Не Найден

Если окно пишет, что backend missing, значит ReaPack-пакет установился не полностью.

Попробуй:

1. `Extensions -> ReaPack -> Synchronize packages`.
2. Обновить `REAPER Audio Tag`.
3. Перезапустить REAPER.

Backend должен лежать здесь:

```text
REAPER/Data/reaper-panns-item-report/bin/
```

## Не Получилось Скачать Модель

Нажми `Download Model` ещё раз. Файл проверяется по размеру и SHA-256, поэтому неполная или битая загрузка безопасно отклоняется.

Ожидаемая модель:

```text
cnn14_waveform_clipwise_opset17.onnx
sha256 deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

Модель весит около 327 MB. На медленном соединении первая загрузка может занять время.

## Checksum Mismatch

Удали битый файл модели из:

```text
REAPER/Data/reaper-panns-item-report/models/
```

Потом запусти `REAPER Audio Tag` и нажми `Download Model` снова.

## Первый Запуск На macOS Медленный

На macOS CoreML может компилировать и кэшировать модель при первом запуске. Следующие запуски обычно быстрее.

## GPU Не Используется

Backend сначала пробует native acceleration:

- macOS: CoreML;
- Windows: DirectML.

Если provider недоступен или падает, backend переключается на CPU, чтобы анализ всё равно завершился.

## Анализ Не Стартует

Проверь, что выбран ровно один audio item перед запуском `REAPER Audio Tag`.

## Debug Export

Используй `REAPER Audio Tag - Debug Export`, если нужно проверить, может ли REAPER экспортировать выбранный item во временный WAV для backend.
