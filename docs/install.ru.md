# Установка

## Поток установки для macOS v1

1. Установи REAPER `7.x`.
2. Установи `ReaImGui` в REAPER через ReaPack.
3. Установи Python `3.11`.
4. Склонируй этот репозиторий локально.
5. Запусти `scripts/bootstrap.command`.
6. Дождись, пока скрипт:
   - создаст локальное runtime-окружение
   - установит packaged Python runtime в управляемый REAPER venv
   - скачает checkpoint `Cnn14_mAP=0.431.pth`
   - проверит checkpoint сильной checksum-проверкой перед активацией runtime
   - запишет runtime config в пользовательскую REAPER data-папку
7. В REAPER импортируй `reaper/PANNs Item Report.lua` в Actions list.
8. Выбери один аудио-item и запусти скрипт.
9. После успешного запуска окно можно не закрывать: выбери другой item и нажми `Another`.

Если ты скачал публичный source release с GitHub, его можно просто распаковать в любую папку и запустить `scripts/bootstrap.command`. Клонирование нужно только для разработки.
Если позже ты подтянешь новую ревизию репозитория, один раз снова запусти `scripts/bootstrap.command`, чтобы управляемый runtime внутри REAPER получил обновлённую версию пакета.

## Где runtime хранит данные

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Model: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- Временные export WAV: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- Export логи: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

## Примечания

- Сам репозиторий остаётся лёгким: большой файл модели хранится вне Git.
- Скрипт запускает только управляемый runtime внутри `Data/reaper-panns-item-report/runtime/venv`.
- Перед tagging аудио сводится в mono и ресемплится в `32 kHz`.
- Отчёт — это clip-level tagging, а не event detection.
- Временные export WAV и завершённые run artifacts удаляются автоматически. Исходные media files скрипт не удаляет.
- Если `ReaImGui` не установлен, скрипт покажет инструкцию вместо падения.
- Если текущая связка ReaImGui/fonts не умеет аккуратно рисовать emoji, UI автоматически переключается на symbol fallback без пустых квадратов.
- Windows намеренно вынесен за рамки v1.
