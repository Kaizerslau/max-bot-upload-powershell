# MAX Audio Uploader

Minimal Windows PowerShell 5.1 utility for uploading one local audio file to MAX Bot API.

## English

### What it does

- Uploads one local audio file to MAX Bot API using `POST /uploads?type=audio`.
- Designed for local `.mp3`, `.m4a`, and `.wav` files.
- Prints the upload URL response, upload raw response, media token, and ready-to-use audio attachment JSON.
- Works on Windows PowerShell 5.1.

### Requirements

- Windows
- PowerShell 5.1
- `curl.exe`
- MAX bot token
- Local audio file

### Setup

1. Download or clone the repository.
2. Copy `.env.example` to `.env`.

```bat
copy .env.example .env
```

3. Open `.env`.
4. Set `MAX_BOT_TOKEN`.
5. Set `AUDIO_FILE_PATH`.

Example `.env`:

```env
MAX_BOT_TOKEN=YOUR_MAX_BOT_TOKEN
AUDIO_FILE_PATH=C:\temp\voice.mp3
```

### Usage

Run:

```bat
run.bat
```

### Successful upload

The upload response from the CDN may look like this:

```xml
<retval>1</retval>
```

This means the file upload succeeded. The script uploads the file as `multipart/form-data` using the field name `data`.

### Result

The script prints a media token and ready audio attachment JSON:

```json
{
  "type": "audio",
  "payload": {
    "token": "TOKEN"
  }
}
```

Full body example for later `POST /messages` usage:

```json
{
  "text": null,
  "attachments": [
    {
      "type": "audio",
      "payload": {
        "token": "TOKEN"
      }
    }
  ]
}
```

### Notes

- `.env` is ignored by Git and must not be committed.
- The script uploads only local files.
- This script only uploads audio and prints the token. It does not send the message.
- If MAX returns `attachment.not.ready` when sending the message, wait a few seconds and retry sending.

---

## Русский

### Что делает скрипт

- Загружает один локальный аудиофайл в MAX Bot API через `POST /uploads?type=audio`.
- Предназначен для локальных файлов `.mp3`, `.m4a` и `.wav`.
- Выводит ответ с upload URL, сырой ответ загрузки, media token и готовый JSON для audio attachment.
- Работает в Windows PowerShell 5.1.

### Требования

- Windows
- PowerShell 5.1
- `curl.exe`
- Токен MAX-бота
- Локальный аудиофайл

### Настройка

1. Скачайте или клонируйте репозиторий.
2. Скопируйте `.env.example` в `.env`.

```bat
copy .env.example .env
```

3. Откройте `.env`.
4. Укажите `MAX_BOT_TOKEN`.
5. Укажите `AUDIO_FILE_PATH`.

Пример `.env`:

```env
MAX_BOT_TOKEN=YOUR_MAX_BOT_TOKEN
AUDIO_FILE_PATH=C:\temp\voice.mp3
```

### Запуск

Запустите:

```bat
run.bat
```

### Успешная загрузка

Ответ загрузки от CDN может выглядеть так:

```xml
<retval>1</retval>
```

Это означает, что файл успешно загружен. Скрипт отправляет файл как `multipart/form-data`, имя поля формы: `data`.

### Результат

Скрипт выводит media token и готовый JSON для audio attachment:

```json
{
  "type": "audio",
  "payload": {
    "token": "TOKEN"
  }
}
```

Пример полного body для последующего `POST /messages`:

```json
{
  "text": null,
  "attachments": [
    {
      "type": "audio",
      "payload": {
        "token": "TOKEN"
      }
    }
  ]
}
```

### Примечания

- `.env` игнорируется Git и не должен попадать в коммит.
- Скрипт загружает только локальные файлы.
- Скрипт только загружает аудио и выводит токен. Он не отправляет сообщение.
- Если при отправке сообщения MAX возвращает `attachment.not.ready`, подождите несколько секунд и повторите отправку.
