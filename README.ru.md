# REAPER Audio Tag

`REAPER Audio Tag` — это action для REAPER для быстрого clip-level анализа аудио. Он экспортирует текущий выбранный аудио-айтем, сводит его в mono, ресемплит в `32 kHz`, запускает локальный `PANNs Cnn14` через управляемый Python runtime и показывает компактный отчёт прямо в DAW: ключевые находки, top detected tags, backend status и подробный режим.

v1 намеренно ограничен: сначала macOS, только один выбранный аудио-айтем за запуск и только `clipwise audio tagging`. Это практичный инструмент для быстрых spot-check проверок, а не timeline/event detector.

<img src="docs/images/reaper-audio-tag-hero.png" alt="Окно отчёта REAPER Audio Tag" width="760">

_Актуальный вид окна REAPER Audio Tag на macOS с wrapping-плашками tags и emoji-иконками из atlas pipeline._

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
   - до `5` top cues в compact view
   - весь ranking tags как wrapping-плашки прямо на основном экране
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

1. Установи REAPER `7.x`.
2. Убедись, что в REAPER установлен `ReaPack`.
3. Через ReaPack установи `ReaImGui: ReaScript binding for Dear ImGui`, затем перезапусти REAPER.
4. Установи Python `3.11`.
5. Скачай актуальный ZIP со страницы [GitHub Releases](https://github.com/dennech/reaper-audio-tag/releases/latest).
6. Распакуй архив в любую папку на Mac.
7. Один раз запусти [`scripts/bootstrap.command`](scripts/bootstrap.command).
8. В REAPER добавь [`reaper/REAPER Audio Tag.lua`](reaper/REAPER%20Audio%20Tag.lua) в Actions list.
9. Выбери ровно один аудио-item.
10. Запусти `REAPER Audio Tag`.

`git clone` нужен только для разработки. Обычная пользовательская установка должна воспроизводиться прямо из скачанного ZIP.

Что делает `bootstrap.command`:

- создаёт управляемое Python-окружение в REAPER app data directory
- устанавливает packaged runtime, который использует скрипт
- автоматически скачивает `Cnn14_mAP=0.431.pth`
- проверяет checkpoint перед активацией
- записывает REAPER-side runtime config

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
- Большой checkpoint хранится только локально и не попадает в Git. В обычном writable checkout bootstrap теперь предпочитает `.local-models/`, а REAPER data dir остаётся fallback-вариантом.
- В первой версии приоритет у надёжности и fallback-поведения, а не у максимального ускорения любой ценой.
- Отчёт — это clip-level tagging-подсказка, а не event detection или timeline localization.
- Подготовка export теперь идёт пошагово на Lua-стороне до запуска Python runtime, поэтому окно остаётся отзывчивым даже на длинных выбранных item.
- Скрипт удаляет только свои временные export WAV, job files и логи внутри `Data/reaper-panns-item-report/{tmp,jobs,logs}`. Исходное аудио и project media он не трогает.
- В compact-отчёте теперь используются bundled Noto Emoji PNG assets вместо системных text-emoji и самодельных sticker-иконок, поэтому теги выглядят одинаково на разных сборках REAPER/ReaImGui.
- Цвета плашек tags теперь жёстко привязаны к bucket-уровням: `Strong` зелёный, `Solid` фиолетовый, `Possible` жёлтый, `Low` красный.
- Исходные emoji-ассеты лежат в `reaper/assets/noto-emoji/`, а `scripts/generate_report_emoji_assets.py` пересобирает self-contained Lua bundle после их обновления.
- Проект вендорит именно Noto Emoji image resources, а не font files. Для bundled PNG-ассетов сохраняй Apache 2.0 notice в `reaper/assets/noto-emoji/LICENSE-APACHE-2.0.txt` и attribution note в `THIRD_PARTY_NOTICES.md`.
- Если image path в конкретной сессии недоступен, UI аккуратно деградирует в plain text без декоративных иконок. На анализ это не влияет.
- Для диагностики export без запуска модели используй `reaper/REAPER Audio Tag - Debug Export.lua`.
