# Документация для фронтенд-разработчиков

## 1. Введение

Это **SPA (Single Page Application)** для работы с S3 Storage Service — микросервисом хранения файлов в распределённой системе управления задачами. Назначение:

- Создание бакетов и папок
- Загрузка, скачивание и перемещение файлов
- Публичное расшаривание файлов по ссылкам

Фронтенд написан на JavaScript (Vanilla JS + Vite), без фреймворков. Подходит как reference-реализация при интеграции S3 API в другие приложения (React, Vue, Angular и т.п.).

---

## 2. Быстрый старт

### Фронтенд

```bash
cd frontend
npm install
npm run dev
```

Приложение будет доступно по адресу `http://localhost:5173`.

### Бэкенд (Docker Compose)

```bash
# Из корня проекта
docker compose up -d

# Подождать ~20 секунд, затем проверить:
# Swagger:  http://localhost:8080/swagger
# Health:   curl http://localhost:8080/health
```

Бэкенд слушает порт `8080`.

---

## 3. Настройка API

### Переменная VITE_API_URL

URL API задаётся через переменную окружения `VITE_API_URL`.

| Значение | Использование |
|----------|---------------|
| По умолчанию | `http://localhost:8080` |
| Явно | Создать файл `.env` в `frontend/` |

### Пример .env

Скопируйте `frontend/.env.example` в `frontend/.env`:

```bash
cp frontend/.env.example frontend/.env
```

Содержимое `.env.example`:

```
VITE_API_URL=http://localhost:8080
```

Измените `VITE_API_URL` при необходимости (например, `http://api.example.com:8080`).

---

## 4. Обязательные заголовки

Для всех запросов к API, кроме **GET /health** и **GET /files/shared/{token}**, обязателен заголовок `X-User-Id`.

| Заголовок | Обязательный | Значение | Назначение |
|-----------|--------------|----------|------------|
| `X-User-Id` | Да (см. исключения выше) | UUID пользователя | Идентификация пользователя |
| `X-Request-Id` | Нет | UUID запроса | Трассировка запросов |
| `Content-Type` | Для JSON body | `application/json` | Тип тела запроса |
| `Content-Type` | Для multipart | Не задавать вручную | Браузер задаёт `multipart/form-data` с boundary |

Без `X-User-Id` API возвращает **401 Unauthorized**.

---

## 5. Примеры вызовов API

### Создать бакет

```bash
curl -X POST http://localhost:8080/files/buckets/create \
  -H "Content-Type: application/json" \
  -H "X-User-Id: 00000000-0000-0000-0000-000000000001" \
  -d '{"name": "Мой бакет", "description": "Тестовый"}'
```

### Список файлов и папок

```bash
curl "http://localhost:8080/files/list?bucket_id=<BUCKET_ID>&parent_folder_id=" \
  -H "X-User-Id: <USER_ID>"
```

Для корня бакета `parent_folder_id` можно опустить или передать пустым.

### Загрузка файла (multipart/form-data)

```bash
curl -X POST http://localhost:8080/files/upload \
  -H "X-User-Id: 00000000-0000-0000-0000-000000000001" \
  -F "file=@/path/to/file.pdf" \
  -F "bucket_id=<BUCKET_ID>" \
  -F "parent_folder_id=<FOLDER_ID>"
```

Поля FormData:

| Поле | Обязательное | Описание |
|------|--------------|----------|
| `file` | Да | Файл для загрузки |
| `bucket_id` | Да | UUID бакета |
| `parent_folder_id` | Нет | UUID папки (корень, если не указано) |
| `name` | Нет | Кастомное имя файла |

### Скачивание файла

```bash
curl "http://localhost:8080/files/download?file_id=<FILE_ID>" \
  -H "X-User-Id: <USER_ID>" \
  -o downloaded-file
```

Ответ — бинарный поток файла. Заголовок `Content-Disposition` может содержать имя файла.

### Пример на fetch (JavaScript)

```javascript
// Создать бакет
const res = await fetch('http://localhost:8080/files/buckets/create', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-User-Id': '00000000-0000-0000-0000-000000000001',
  },
  body: JSON.stringify({ name: 'Мой бакет', description: 'Тестовый' }),
});
const json = await res.json();
```

```javascript
// Загрузка файла (multipart)
const formData = new FormData();
formData.append('file', fileInput.files[0]);
formData.append('bucket_id', bucketId);
formData.append('parent_folder_id', folderId || '');

const res = await fetch('http://localhost:8080/files/upload', {
  method: 'POST',
  headers: {
    'X-User-Id': userId,
    // НЕ задавать Content-Type — браузер установит multipart
  },
  body: formData,
});
```

---

## 6. Формат ответов

### Успешный ответ

```json
{
  "success": true,
  "data": { ... }
}
```

Поле `data` содержит данные в зависимости от endpoint (объект бакета, массив файлов и т.д.).

### Ошибка

```json
{
  "success": false,
  "error": {
    "code": "CODE",
    "message": "Текстовое описание ошибки"
  }
}
```

| Поле | Описание |
|------|----------|
| `code` | Код ошибки (например, `UNAUTHORIZED`, `NOT_FOUND`) |
| `message` | Человекочитаемое сообщение |

---

## 7. Структура проекта frontend/

```
frontend/
├── index.html           # Точка входа HTML
├── package.json         # Зависимости (Vite)
├── vite.config.js       # Конфигурация Vite
├── .env.example         # Шаблон переменных окружения
└── src/
    ├── main.js          # Инициализация приложения, роутинг, UI header (демо User ID)
    ├── config.js        # API_BASE_URL из VITE_API_URL
    ├── store.js         # Состояние приложения (userId, buckets, files и т.д.)
    ├── api/
    │   ├── client.js    # Базовый HTTP-клиент (X-User-Id, X-Request-Id, parseResponse)
    │   └── s3.js        # Обёртки над endpoints (listBuckets, createBucket, uploadFile и др.)
    ├── components/
    │   ├── BucketList.js   # Список бакетов, создание/удаление
    │   ├── FileList.js     # Список файлов/папок, загрузка, скачивание, удаление
    │   ├── Uploader.js     # UI загрузки файлов
    │   ├── Breadcrumb.js   # Навигация по папкам
    │   └── Modals.js       # Модальные окна (создание бакета, папки)
    └── styles/
        ├── main.css     # Базовые стили
        └── app.css      # Стили приложения
```

---

## 8. Демо-режим

Для запуска SPA **в standalone** (без API Gateway и сессий) используется **mock X-User-Id**:

- В шапке приложения есть поле «User ID (демо)»
- По умолчанию: `00000000-0000-0000-0000-000000000001`
- Значение сохраняется в `localStorage` под ключом `s3-demo-user-id`
- Все запросы к API отправляются с этим UUID в заголовке `X-User-Id`

В production окружении API Gateway подставляет реальный `X-User-Id` после валидации сессии. SPA тогда должен брать userId из авторизации, а не из поля ввода.

---

## 9. CORS

S3 Service поддерживает CORS. При запросах с другого origin (например, `http://localhost:5173` → `http://localhost:8080`) заголовки CORS обрабатываются на стороне S3.

При проблемах с CORS:

- Проверьте, что в ответе S3 присутствуют заголовки `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods` и т.д.
- Если S3 стоит за Nginx/прокси — убедитесь, что CORS-заголовки пробрасываются
- При ошибке «Failed to fetch» или «blocked by CORS» проверьте origin в настройках S3 или прокси

---

## 10. Коды ошибок HTTP

| Код | Описание |
|-----|----------|
| **401** | Unauthorized — не передан или некорректен заголовок `X-User-Id` |
| **404** | Not Found — бакет, файл или папка не найдены |
| **413** | Payload Too Large — размер файла превышает лимит (например, 100 MB) |
| **429** | Too Many Requests — превышен rate limit |
| **507** | Insufficient Storage — квота хранилища исчерпана |

Все ошибки возвращаются в формате `{"success": false, "error": {"code": "...", "message": "..."}}`.
