# REAPER PANNs Item Report

`REAPER PANNs Item Report` — это action для REAPER для быстрого clip-level анализа аудио. Он экспортирует текущий выбранный аудио-айтем, сводит его в mono, ресемплит в `32 kHz`, запускает локальный `PANNs Cnn14` через управляемый Python runtime и показывает компактный отчёт прямо в DAW: ключевые находки, top detected tags, backend status и подробный режим.

v1 намеренно ограничен: сначала macOS, только один выбранный аудио-айтем за запуск и только `clipwise audio tagging`. Это практичный инструмент для быстрых spot-check проверок, а не timeline/event detector.

## Статус

- Целевая первая версия: `macOS Apple Silicon + Intel Mac`
- Windows: отдельный следующий этап после стабилизации macOS
- Модель в v1: только `clipwise audio tagging`
- UI-зависимость: `ReaImGui`

## Что делает проект

1. Экспортирует именно выбранный участок take из REAPER через `CreateTakeAudioAccessor` и `GetAudioAccessorSamples`.
2. Сводит аудио в mono и ресемплит его в `32 kHz` перед tagging.
3. Передаёт JSON-запрос локальному Python runtime.
4. Запускает инференс PANNs с fallback `MPS -> CPU` на Apple Silicon и `CPU` на Intel Mac.
5. Показывает:
   - компактное summary с интересными находками
   - до `5` top cues и `6` top tags в compact view
   - backend и timing status
   - подробный список top predictions
   - кнопку `Another`, чтобы выбрать другой item и пересчитать отчёт без закрытия окна

## Минимальные требования

- REAPER `7.x`
- установленный `ReaImGui`
- macOS Apple Silicon или Intel Mac
- Python `3.11`
- свободное место под окружение runtime и checkpoint модели

## Быстрый старт

1. Склонируй репозиторий.
2. Один раз запусти [`scripts/bootstrap.command`](scripts/bootstrap.command).
3. В REAPER добавь [`reaper/PANNs Item Report.lua`](reaper/PANNs%20Item%20Report.lua) в Actions list.
4. Выбери ровно один аудио-item.
5. Запусти `PANNs Item Report`.

Если ты ставишь публичный релиз, достаточно скачать source archive и запустить `scripts/bootstrap.command`. Клонирование нужно только для разработки.

Подробная установка:

- EN: [`docs/install.md`](docs/install.md)
- RU: [`docs/install.ru.md`](docs/install.ru.md)

Разбор проблем:

- EN: [`docs/troubleshooting.md`](docs/troubleshooting.md)
- RU: [`docs/troubleshooting.ru.md`](docs/troubleshooting.ru.md)

## Разработка

- Python-тесты: `python3 tests/scripts/run_python_tests.py --scope python`
- Интеграционные тесты: `python3 tests/scripts/run_python_tests.py --scope integration`
- Lua-тесты: `lua tests/lua/run_tests.lua`

## Структура

- [`reaper/`](reaper): Lua action, UI, экспорт аудио, bridge к runtime
- [`runtime/`](runtime): Python runtime package, model adapter, bootstrap logic
- [`tests/`](tests): покрытие Python, Lua и integration
- [`scripts/`](scripts): bootstrap helpers

## Безопасность и приватность

- Runtime использует только управляемое virtualenv в REAPER data directory и не доверяет внешнему пути к Python из `config.json`.
- Checkpoint проверяется перед использованием и хранится вне Git в пользовательской папке REAPER.
- История репозитория была очищена от случайно закоммиченных локальных путей. Логин владельца GitHub остаётся частью URL репозитория, потому что проект остаётся под текущим аккаунтом.

## Примечания

- В проект vendored нужная часть официального PANNs-кода для загрузки `Cnn14`.
- Большой checkpoint скачивается в пользовательскую REAPER data-папку и не хранится в Git.
- В первой версии приоритет у надёжности и fallback-поведения, а не у максимального ускорения любой ценой.
- Отчёт — это clip-level tagging-подсказка, а не event detection или timeline localization.
- Скрипт удаляет только свои временные export WAV, job files и логи внутри `Data/reaper-panns-item-report/{tmp,jobs,logs}`. Исходное аудио и project media он не трогает.
- Если текущая связка ReaImGui/font stack не показывает emoji аккуратно, UI автоматически деградирует в playful symbol chips без пустых квадратиков.
- Для диагностики export без запуска модели используй `reaper/PANNs Item Report - Debug Export.lua`.
