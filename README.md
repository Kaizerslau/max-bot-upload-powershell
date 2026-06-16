# MAX File Uploader

Небольшая утилита для Windows PowerShell 5.1, которая загружает один локальный файл в MAX Bot API.

Поддерживаются типы:

- `image`
- `video`
- `audio`
- `file`

`photo` больше не поддерживается MAX. Используйте `image`.

## Что делает скрипт

- Запрашивает upload URL через `POST /uploads?type=...`.
- Загружает один локальный файл как `multipart/form-data` с именем поля `data`.
- Автоматически определяет тип загрузки по расширению файла.
- Передаёт подходящий MIME type для известных расширений.
- Выводит ответ upload URL, сырой ответ загрузки, готовый attachment JSON и пример body для `POST /messages`.

## Требования

- Windows
- PowerShell 5.1
- `curl.exe`
- Токен MAX-бота
- Локальный файл для загрузки

## Настройка

Скопируйте пример:

```bat
copy .env.example .env
```

В `.env` обычно нужен только токен:

```env
MAX_BOT_TOKEN=YOUR_MAX_BOT_TOKEN
MAX_UPLOAD_TYPE=auto
```

Путь к файлу удобнее не хранить в `.env`: можно перетащить файл на `run.bat`, передать путь аргументом или вставить путь при запуске.

Если всё-таки нужен файл по умолчанию, можно добавить:

```env
MAX_FILE_PATH=C:\temp\voice.mp3
```

Старый параметр `AUDIO_FILE_PATH` ещё поддерживается, но лучше перейти на новый способ.

## Запуск

Запуск с вводом пути:

```bat
run.bat
```

Можно перетащить файл на `run.bat`.

Запуск с путём:

```bat
run.bat "C:\temp\picture.png"
```

Запуск с явным типом:

```bat
run.bat "C:\temp\unknown.bin" file
```

Можно вызвать PowerShell-скрипт напрямую:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\upload-max-file.ps1 -FilePath "C:\temp\movie.mp4" -UploadType video
```

## Автоопределение типа

При `MAX_UPLOAD_TYPE=auto` расширения сопоставляются так:

- Изображения: `.jpg`, `.jpeg`, `.png`, `.gif`, `.tiff`, `.tif`, `.bmp`, `.heic`
- Видео: `.mp4`, `.mov`, `.mkv`, `.webm`, `.matroska`
- Аудио: `.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.opus`, `.flac`
- Всё остальное: `file`

Поддерживаемые типы MAX: `image`, `video`, `audio`, `file`.

## Результат

Скрипт выводит готовый attachment JSON. Точная форма payload зависит от ответа MAX и типа файла.

```json
{
  "type": "file",
  "payload": {
    "fileId": 123,
    "token": "TOKEN"
  }
}
```

И пример полного body для последующего `POST /messages`:

```json
{
  "text": null,
  "attachments": [
    {
      "type": "file",
      "payload": {
        "fileId": 123,
        "token": "TOKEN"
      }
    }
  ]
}
```

Для `audio` и `video` MAX возвращает token при создании upload URL. Для `image` и `file` token берётся из ответа загрузки.

Реальные тесты API подтвердили `file`, `image`, `audio` с MP3 и `video` с MP4. Для WAV во время тестирования MAX вернул `415 Unsupported Media Type`; если это повторится, конвертируйте аудио в MP3 и попробуйте снова.

Если MAX возвращает `attachment.not.ready` при отправке сообщения, подождите несколько секунд и повторите отправку.

---

# MAX File Uploader: English

Minimal Windows PowerShell 5.1 utility for uploading one local file to MAX Bot API.

The script supports all current MAX upload types:

- `image`
- `video`
- `audio`
- `file`

`photo` is not supported by MAX anymore. Use `image`.

## What It Does

- Requests an upload URL from `POST /uploads?type=...`.
- Uploads one local file as `multipart/form-data` with the field name `data`.
- Detects the upload type automatically from the file extension by default.
- Sends a matching MIME type for known extensions.
- Prints the upload URL response, raw upload response, ready attachment JSON, and example body for `POST /messages`.

## Requirements

- Windows
- PowerShell 5.1
- `curl.exe`
- MAX bot token
- Local file to upload

## Setup

Copy the example environment file:

```bat
copy .env.example .env
```

Open `.env` and set your bot token:

```env
MAX_BOT_TOKEN=YOUR_MAX_BOT_TOKEN
MAX_UPLOAD_TYPE=auto
```

Usually the file path should not live in `.env`. Pass it at launch, drag a file onto `run.bat`, or paste the path when prompted.

Optional fallback:

```env
MAX_FILE_PATH=C:\temp\voice.mp3
```

The old `AUDIO_FILE_PATH` setting is still accepted for compatibility, but `MAX_FILE_PATH` is preferred if you really want a default file in `.env`.

## Usage

Run and paste the file path when prompted:

```bat
run.bat
```

Or drag-and-drop a file onto `run.bat`.

Or pass the file path directly:

```bat
run.bat "C:\temp\picture.png"
```

Force a type if auto-detection is not what you want:

```bat
run.bat "C:\temp\unknown.bin" file
```

You can also call the PowerShell script directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\upload-max-file.ps1 -FilePath "C:\temp\movie.mp4" -UploadType video
```

## Auto Type Detection

With `MAX_UPLOAD_TYPE=auto`, the script maps extensions like this:

- Images: `.jpg`, `.jpeg`, `.png`, `.gif`, `.tiff`, `.tif`, `.bmp`, `.heic`
- Videos: `.mp4`, `.mov`, `.mkv`, `.webm`, `.matroska`
- Audio: `.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.opus`, `.flac`
- Anything else: `file`

Supported MAX upload types are `image`, `video`, `audio`, and `file`.

## Result

The script prints a ready attachment JSON. Exact payload shape depends on MAX response and file type.

```json
{
  "type": "file",
  "payload": {
    "fileId": 123,
    "token": "TOKEN"
  }
}
```

And a full body example for later `POST /messages` usage:

```json
{
  "text": null,
  "attachments": [
    {
      "type": "file",
      "payload": {
        "fileId": 123,
        "token": "TOKEN"
      }
    }
  ]
}
```

For `audio` and `video`, MAX returns the token when the upload URL is created. For `image` and `file`, the token is taken from the upload response.

Real API testing confirmed `file`, `image`, `audio` with MP3, and `video` with MP4. MAX returned `415 Unsupported Media Type` for WAV during testing; if that happens, convert the audio to MP3 and retry.

If MAX returns `attachment.not.ready` when sending the message, wait a few seconds and retry sending.
