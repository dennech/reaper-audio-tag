# Troubleshooting

## Не хватает `ReaImGui`

- Открой `Extensions -> ReaPack -> Browse Packages...`.
- Найди `ReaImGui: ReaScript binding for Dear ImGui`.
- Установи пакет и перезапусти REAPER.

## В Actions list нет `REAPER Audio Tag: Configure`

- Убедись, что пакет `REAPER Audio Tag` установлен через ReaPack URL этого проекта.
- Если нужно, заново импортируй:

  `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

- Переустанови пакет из ReaPack и заново обнови Actions list.

## `Configure` пишет, что Python 3.11 не найден

- Проверь путь в Terminal:

```bash
"/path/to/python" --version
```

- Используй именно файл Python executable из своего локального venv, а не папку и не случайный системный binary.
- Хорошие примеры:
  `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/python`
  `/opt/homebrew/bin/python3.11`
  `/usr/local/bin/python3.11`
- Длинный путь вида `Cellar/.../Python.framework/...` тоже может работать, но локальный venv path предпочтительнее.
- Если нужно, пересоздай venv через `python3.11 -m venv ...`.

## `Configure` пишет, что не хватает зависимостей

- Активируй тот же environment, который выбрал в `Configure`.
- Переустанови pinned dependencies:

```bash
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

## `Configure` отклоняет файл модели

- Проверь, что имя файла ровно `Cnn14_mAP=0.431.pth`.
- Выбирай сам файл, а не папку, в которой он лежит.
- Проверь checksum:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

- Ожидаемое значение:

  `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`

## Основной action всё время открывает `Configure`

- Сохрани новую конфигурацию через `REAPER Audio Tag: Configure`.
- Убедись, что путь к Python всё ещё существует и executable.
- Убедись, что файл модели всё ещё существует по сохранённому пути.
- Если раньше использовался bundled-runtime flow, пересохрани config в новом прозрачном формате.

## `Configure` пишет, что в пакете не хватает runtime source

- Открой `Extensions -> ReaPack -> Synchronize packages`.
- Обнови `REAPER Audio Tag` до последней версии из ReaPack URL этого проекта.
- Снова открой `REAPER Audio Tag: Configure`.
- Если в установленном пакете по-прежнему есть только `reaper/...`, но нет `reaper/runtime/src/...`, переустанови пакет через ReaPack.

## Первый запуск медленный

- Это нормально для первого запуска.
- Импорт `torch` и загрузка модели могут занимать заметное время.

## Где проект хранит свои данные

- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

## Developer note

- Source checkout может использовать локальный venv и `scripts/create_local_venv_macos.sh`.
- Это не входит в обычный публичный install flow.
