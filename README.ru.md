# REAPER Audio Tag

`REAPER Audio Tag` — это action для REAPER для быстрого clip-level анализа аудио.

<img src="docs/images/reaper-audio-tag-hero.png" alt="Окно REAPER Audio Tag" width="760">

_Текущее окно отчёта REAPER Audio Tag на macOS._

## Статус

- только macOS
- поддерживаются Apple Silicon и Intel Mac
- Windows пока недоступен
- только один выбранный audio item за раз
- только clipwise audio tagging
- нужен `ReaImGui`

## Что входит в пакет

Пакет ReaPack включает:

- Lua actions и UI
- локальный Python runtime source code проекта

Пакет ReaPack **не** включает:

- сам Python
- сторонние Python-пакеты вроде `torch`
- файл модели PANNs

Это сделано специально. Настройка должна оставаться прозрачной и проверяемой.

## Что делает проект

1. Экспортирует точно выбранный диапазон take из REAPER.
2. Сводит аудио в mono.
3. Ресемплит его в `32 kHz`.
4. Запускает локальный `PANNs Cnn14`.
5. Показывает компактный отчёт внутри REAPER.

Это практичный инструмент для clip-level анализа. Это **не** детектор событий на таймлайне.

## Приватность и доверие

- Аудио остаётся на твоей машине.
- Никакого облачного processing.
- Никакого скрытого installer inside REAPER.
- Никакой автоматической загрузки Python из REAPER.
- Никакой автоматической загрузки модели из REAPER.
- Ты сам выбираешь путь к Python.
- Ты сам выбираешь путь к модели.
- Скрипт валидирует эти пути до запуска анализа.

## Требования

- REAPER `7.x`
- `ReaPack`
- `ReaImGui`
- macOS Apple Silicon или Intel Mac
- Python `3.11`
- достаточно места на диске под Python environment и файл модели

## Важные замечания по ручной установке

- пока только macOS
- сейчас проект использует собственный URL ReaPack-репозитория
- REAPER не устанавливает Python и не скачивает модель за тебя
- нужный файл модели `Cnn14_mAP=0.431.pth` большой, около `327 MB`
- v1 намеренно консервативен: один выбранный item за раз, только локальный inference, только clipwise tagging

## Установка

### 1. Установи пакет через ReaPack

Пока установка идёт через собственный ReaPack-репозиторий проекта.

1. Установи REAPER `7.x`.
2. Если `ReaPack` ещё не установлен, поставь его с [reapack.com](https://reapack.com/).
3. В REAPER открой `Extensions -> ReaPack -> Import repositories...`.
4. Добавь этот URL репозитория:

```text
https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml
```

5. Открой `Extensions -> ReaPack -> Browse Packages...`.
6. Найди `REAPER Audio Tag`.
7. Установи пакет.

### 2. Установи ReaImGui

1. В ReaPack найди `ReaImGui: ReaScript binding for Dear ImGui`.
2. Установи пакет.
3. Перезапусти REAPER.

### 3. Установи Python 3.11

Установи Python `3.11` из источника, которому доверяешь.

Рекомендуемый вариант: официальный installer с python.org.

После установки проверь в Terminal:

```bash
python3.11 --version
```

### 4. Создай локальное Python environment и установи зависимости

Проект ожидает локальное Python environment, в котором уже стоят нужные зависимости.

Рекомендуемое место:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv
```

Создай environment:

```bash
mkdir -p "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report"
python3.11 -m venv "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv"
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install --upgrade pip
```

Установи Python-пакеты:

```bash
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

Путь к Python, который потом нужно указать в REAPER:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python
```

Опциональный helper script для source checkout или отдельной загрузки репозитория:

```bash
./scripts/create_local_venv_macos.sh
```

Этот helper остаётся полностью опциональным. Он только создаёт venv, ставит pinned dependencies и печатает путь к Python для `Configure`.

### 5. Скачай модель вручную

Скачай этот файл самостоятельно:

- имя файла: `Cnn14_mAP=0.431.pth`
- ожидаемый SHA-256: `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`
- размер: примерно `327 MB`

Рекомендуемый источник:

- Zenodo: [Cnn14_mAP=0.431.pth](https://zenodo.org/records/3987831/files/Cnn14_mAP%3D0.431.pth)

Сохрани исходное имя файла без переименования.

Проверь checksum перед использованием:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

Ожидаемый результат:

```text
0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31
```

### 6. Настрой пути внутри REAPER

Открой Action List и запусти:

```text
REAPER Audio Tag: Configure
```

Укажи:

- **Python executable**: файл executable внутри твоего environment, обычно `.../venv/bin/python`
- **Model file**: сам файл `Cnn14_mAP=0.431.pth`

Примеры:

- предпочтительный путь к Python: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
- допустимый Homebrew path: `/opt/homebrew/bin/python3.11`
- путь к модели: `/path/to/Cnn14_mAP=0.431.pth`

Потом используй:

- `Validate`
- `Save`

<!-- TODO: Заменить эту ссылку на реальный скрин Configure-окна перед следующим релизом. -->
![Окно REAPER Audio Tag Configure](docs/images/reaper-audio-tag-configure.png)

_Ожидаемый вид Configure: путь к Python, путь к модели, состояние валидации и сохранение._

### 7. Запусти отчёт

1. Выбери ровно один audio item.
2. Запусти:

```text
REAPER Audio Tag
```

Если конфигурация отсутствует или невалидна, скрипт откроет `Configure`, а не попытается запускать анализ.

## Что важно на первом запуске

- Первый запуск анализа может быть заметно медленнее, потому что загружаются Python-пакеты и модель.
- На Apple Silicon backend может использовать `MPS` с fallback на `CPU`.
- На Intel Mac анализ идёт на `CPU`.
- v1 намеренно делает ставку на надёжность.

## Внешние инструменты

`FFmpeg` **не нужен** для текущей версии.

Аудио экспортируется напрямую из REAPER, поэтому отдельного шага установки `ffmpeg` в обычном user flow нет.

## Где что хранится

Рекомендуемая раскладка:

- REAPER-side config и временные данные:
  - `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`
- Python environment:
  - `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/`
- Файл модели:
  - где угодно, если `Configure` указывает на него правильно

Пакет REAPER хранит только свой config, логи, jobs и временные файлы в REAPER data directory.

## Troubleshooting

### Не хватает ReaImGui

Установи `ReaImGui: ReaScript binding for Dear ImGui` через ReaPack и перезапусти REAPER.

### Неверный путь к Python

Убедись, что в `Configure` указан именно файл Python executable из твоего локального environment, а не папка и не случайный системный путь.

Хорошие примеры:

- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
- `/opt/homebrew/bin/python3.11`
- `/usr/local/bin/python3.11`

Длинный путь вида `Cellar/.../Python.framework/...` тоже может работать, но локальный venv path предпочтительнее.

### Не хватает Python-зависимостей

Активируй тот же environment и переустанови нужные пакеты:

```bash
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

### `Configure` пишет, что в пакете не хватает runtime source

- Открой `Extensions -> ReaPack -> Synchronize packages`.
- Обнови `REAPER Audio Tag` до последней версии.
- Снова открой `REAPER Audio Tag: Configure`.
- Если после установки в пакете есть только `reaper/...`, но нет `reaper/runtime/src/...`, переустанови пакет из ReaPack URL этого проекта.

### Модель отклоняется

Проверь всё сразу:

- имя файла должно быть ровно `Cnn14_mAP=0.431.pth`
- загрузка должна быть полной
- SHA-256 должен совпадать

### Первый запуск медленный

Это нормально. Загрузка `torch` и модели на первом запуске может занимать заметное время.

## Удаление

Чтобы удалить проект полностью:

1. Удали пакет из ReaPack.
2. Удали папку данных проекта, если она больше не нужна:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/
```

3. Удали файл модели, если он больше не нужен.

## Разработка

Developer и source-checkout workflow можно документировать отдельно.

Обычным пользователям не нужно клонировать репозиторий, чтобы пользоваться скриптом.

## Примечания

- Проект вендорит официальный PANNs model code, нужный для загрузки `Cnn14`.
- Подготовка export идёт инкрементально на Lua-стороне до запуска Python inference, поэтому окно остаётся отзывчивым на длинных item.
- Скрипт удаляет только свои временные export WAV, job files и логи внутри `Data/reaper-panns-item-report/{tmp,jobs,logs}`. Исходное аудио и project media он не трогает.
- Compact report использует bundled Noto Emoji PNG assets вместо системных emoji, поэтому теги выглядят одинаково в разных сборках REAPER и ReaImGui.
- Более широкий публичный ReaPack-канал можно оценить позже. Пока проект использует собственный URL репозитория напрямую.

## Лицензия

MIT
