# Установка

## Поток установки для macOS v1

1. Установи REAPER `7.x`.
2. Установи `ReaImGui` в REAPER через ReaPack.
3. Установи Python `3.11`.
4. Склонируй этот репозиторий локально.
5. Запусти `scripts/bootstrap.command`.
6. Дождись, пока скрипт:
   - создаст локальное runtime-окружение
   - поставит Python-зависимости
   - скачает checkpoint `Cnn14_mAP=0.431.pth`
   - проверит checkpoint сильной checksum-проверкой перед активацией runtime
   - запишет runtime config в пользовательскую REAPER data-папку
7. В REAPER импортируй `reaper/PANNs Item Report.lua` в Actions list.
8. Выбери один аудио-item и запусти скрипт.

## Где runtime хранит данные

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Model: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs и логи: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`

## Примечания

- Сам репозиторий остаётся лёгким: большой файл модели хранится вне Git.
- Скрипт запускает только управляемый runtime внутри `Data/reaper-panns-item-report/runtime/venv`.
- Если `ReaImGui` не установлен, скрипт покажет инструкцию вместо падения.
- Windows намеренно вынесен за рамки v1.
