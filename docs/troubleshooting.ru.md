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
- Сначала удали частично скачанный checkpoint из `.local-models/`, а если bootstrap работал через fallback — из REAPER model directory.
- Снова запусти `scripts/bootstrap.command`.

## Скрипт не принимает выбранный item

- Проверь, что выбран ровно один item.
- Проверь, что активный take — аудио, а не MIDI.
- Если отчёт уже открыт, не закрывай окно: выбери новый item и нажми `Another`.

## REAPER начинает тормозить при открытии отчёта

- Убедись, что у тебя последняя версия скрипта, и запусти action ещё раз.
- Теперь export готовится пошагово, поэтому перед запуском runtime должен кратко появляться этап `Preparing audio...`.
- Если тормоза остаются, сохрани текущий runtime или export log и отметь, просадка начинается на `Preparing audio...`, уже на `Listening...` или только после появления готового отчёта.
- Временная on-screen диагностика была убрана после стабилизации atlas-based icon path, поэтому теперь для разборов используются обычные логи, а не дополнительные кнопки в окне отчёта.

## В compact view не видны цветные иконки

- В текущей версии используются bundled Noto Emoji PNG assets, а не системные emoji.
- Если в чипах виден только текст без иконок, значит image decode/render path в этой сессии REAPER недоступен.
- На качество анализа это не влияет: это только presentation fallback.
- Обычно достаточно заново запустить скрипт, если UI-сессия оказалась в плохом состоянии.

## Хочу посмотреть export-диагностику без запуска модели

- Запусти `reaper/REAPER Audio Tag - Debug Export.lua`.
- Он экспортирует выбранный take range, пишет diagnostics log и останавливается до шага Python runtime.

## Боюсь, что временные файлы захламляют систему

- Скрипт создаёт только временные WAV, job files и логи внутри REAPER app data directory.
- Эти временные артефакты автоматически убираются после завершённого run, `Retry`, `Another` и закрытия окна.
- Исходные source audio files и project media не удаляются.

## Теги кажутся слишком общими

- Текущий runtime делает только clip-level tagging.
- Перед инференсом аудио сводится в mono и ресемплится в `32 kHz`.
- Этот отчёт лучше использовать как быстрый cueing-инструмент, а не как точный event detector.
