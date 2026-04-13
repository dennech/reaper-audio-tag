# Решение проблем

## Скрипт пишет, что не найден ReaImGui

- Открой ReaPack внутри REAPER.
- Установи `ReaImGui: ReaScript binding for Dear ImGui`.
- Перезапусти REAPER.

## Скрипт просит запустить bootstrap

- Запусти `scripts/bootstrap.command`.
- Проверь, что `config.json` появился в REAPER user data directory.
- Не подсовывай системный Python вручную: скрипт ожидает управляемый runtime в `Data/reaper-panns-item-report/runtime/venv`.
- Для development-only editable install используй `scripts/bootstrap_runtime.sh --dev`.

## Runtime ушёл в CPU fallback

- На Apple Silicon это нормально, если `MPS` недоступен или работает нестабильно.
- Runtime специально выбирает безопасный fallback вместо крэша.

## Не скачивается модель

- Проверь интернет.
- Удали частично скачанный checkpoint из папки модели runtime.
- Снова запусти `scripts/bootstrap.command`.

## Скрипт не принимает выбранный item

- Проверь, что выбран ровно один item.
- Проверь, что активный take — аудио, а не MIDI.
- Если отчёт уже открыт, не закрывай окно: выбери новый item и нажми `Another`.

## В compact view видны symbols, а не emoji

- Открой `More` и переключи `Icons` между `Auto`, `Emoji` и `Symbols`.
- `Auto` использует системный font fallback ReaImGui для mixed emoji text.
- `Symbols` принудительно включает безопасный symbol fallback, чтобы UI оставался читаемым даже на сборках без корректного emoji-rendering.
- На качество анализа этот fallback не влияет.

## Хочу посмотреть export-диагностику без запуска модели

- Запусти `reaper/PANNs Item Report - Debug Export.lua`.
- Он экспортирует выбранный take range, пишет diagnostics log и останавливается до шага Python runtime.

## Боюсь, что временные файлы захламляют систему

- Скрипт создаёт только временные WAV, job files и логи внутри REAPER app data directory.
- Эти временные артефакты автоматически убираются после завершённого run, `Retry`, `Another` и закрытия окна.
- Исходные source audio files и project media не удаляются.

## Теги кажутся слишком общими

- Текущий runtime делает только clip-level tagging.
- Перед инференсом аудио сводится в mono и ресемплится в `32 kHz`.
- Этот отчёт лучше использовать как быстрый cueing-инструмент, а не как точный event detector.
