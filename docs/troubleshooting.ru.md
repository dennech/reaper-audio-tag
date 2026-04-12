# Решение проблем

## Скрипт пишет, что не найден ReaImGui

- Открой ReaPack внутри REAPER.
- Установи `ReaImGui: ReaScript binding for Dear ImGui`.
- Перезапусти REAPER.

## Скрипт просит запустить bootstrap

- Запусти `scripts/bootstrap.command`.
- Проверь, что `config.json` появился в REAPER user data directory.
- Не подсовывай системный Python вручную: скрипт ожидает управляемый runtime в `Data/reaper-panns-item-report/runtime/venv`.

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
