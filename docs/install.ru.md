# Установка

## Публичный поток установки для macOS

### 1. Установи основные зависимости

1. Установи REAPER `7.x`.
2. Установи Python `3.11`.

### 2. Установи ReaPack и ReaImGui в REAPER

1. Открой REAPER.
2. Проверь, есть ли меню `Extensions -> ReaPack -> Browse Packages...`.
3. Если этого меню нет, сначала установи ReaPack, перезапусти REAPER и вернись к этому шагу.
4. Открой `Extensions -> ReaPack -> Browse Packages...`.
5. Найди `ReaImGui: ReaScript binding for Dear ImGui`.
6. Установи пакет.
7. Перезапусти REAPER.

### 3. Скачай ZIP проекта

1. Открой страницу [GitHub Releases](https://github.com/dennech/reaper-audio-tag/releases/latest).
2. Скачай актуальный ZIP этого проекта.
3. Распакуй архив в любую папку на Mac.

Для обычной установки `git clone` не нужен. Клонирование остаётся только для разработки.

### 4. Настрой runtime и модель PANNs

1. Открой распакованную папку.
2. Запусти `scripts/bootstrap.command`.
3. Дождись завершения.

`bootstrap.command` — это публичная точка входа. Под капотом он вызывает `scripts/bootstrap_runtime.sh`, но обычному пользователю нужно запускать именно `bootstrap.command`.

Что этот шаг делает автоматически:

- создаёт управляемое runtime-окружение
- устанавливает packaged Python runtime в REAPER-managed venv
- скачивает checkpoint `Cnn14_mAP=0.431.pth`
- проверяет checkpoint перед активацией
- записывает runtime config в пользовательскую REAPER data-папку

В обычном сценарии модель PANNs вручную не ставится. Bootstrap сам скачивает и проверяет её за пользователя.

### 5. Добавь action в REAPER

1. В REAPER импортируй `reaper/REAPER Audio Tag.lua` в Actions list.
2. Выбери один аудио-item.
3. Запусти скрипт.
4. После успешного запуска окно можно не закрывать: выбери другой item и нажми `Another`.

## Настройка для разработчиков

- Разработчики по-прежнему могут клонировать репозиторий и запускать `scripts/bootstrap.command` из checkout.
- Если позже ты подтянешь новую ревизию, снова запусти `scripts/bootstrap.command`, чтобы управляемый runtime получил обновлённую версию пакета.

## Где runtime хранит данные

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Preferred model cache: `<repo>/.local-models`
- Fallback model cache: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- Временные export WAV: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- Export логи: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

## Примечания

- Сам репозиторий остаётся лёгким: большой файл модели хранится локально вне Git, а `.local-models/` добавлена в ignore.
- Скрипт запускает только управляемый runtime внутри `Data/reaper-panns-item-report/runtime/venv`.
- Перед tagging аудио сводится в mono и ресемплится в `32 kHz`.
- Отчёт — это clip-level tagging, а не event detection.
- Временные export WAV и завершённые run artifacts удаляются автоматически. Исходные media files скрипт не удаляет.
- Если `ReaImGui` не установлен, скрипт покажет инструкцию вместо падения.
- В compact UI теперь используются bundled Noto Emoji PNG assets, поэтому он больше не зависит от системного emoji-rendering.
- Pinned upstream source для этих ассетов описан в `reaper/assets/noto-emoji/README.md`.
- Если image path в конкретной сессии REAPER недоступен, UI аккуратно деградирует в plain text без пустых квадратов.
- Windows намеренно вынесен за рамки v1.
