# S3 Storage Service

Микросервис хранения файлов, спроектированный для работы в составе распределённой системы (например, системы управления задачами или корпоративного портала). Предоставляет REST API для создания бакетов, папок, загрузки и скачивания файлов, перемещения, удаления и публичного расшаривания через ссылки.

**Стек:** C++17 (Drogon) + PostgreSQL + Vanilla JS (Vite) frontend.

---

## О проекте

S3 Storage Service — это самодостаточное приложение, которое можно запустить одним `docker compose up`. В него входят:

- **Бэкенд (C++ Drogon)** — REST API с ~14 эндпоинтами. Бизнес-логика вынесена в отдельные сервисы (Bucket, File, Storage, Share, Database). Используются фильтры для проверки авторизации, CORS и rate limiting. Soft delete: записи помечаются `deleted_at`, через 7 дней CleanupService выполняет физическое удаление файлов и записей.

- **Фронтенд (Vanilla JS + Vite)** — Single Page Application без фреймворков. Веб-интерфейс для работы с бакетами, папками и файлами: создание, загрузка, скачивание, перемещение, удаление, создание публичных ссылок. Состояние хранится в централизованном store; все запросы идут через api/client.js с заголовком X-User-Id.

- **PostgreSQL** — хранение метаданных: бакеты, файлы, папки, публичные ссылки. Миграции применяются автоматически при первом запуске контейнера.

- **Файловое хранилище** — тела файлов на диске. Структура путей: `{base}/users/{user_id}/buckets/{bucket_id}/files/{storage_key}`.

Сервис рассчитан на работу за API Gateway: проверка сессий и CSRF выполняется в Gateway, S3 доверяет заголовку `X-User-Id`. В демо-режиме User ID задаётся вручную в веб-интерфейсе.

### Основные возможности

| Категория | Функции |
|-----------|---------|
| Бакеты | Создание, список, удаление, проверка квоты (10 GB по умолчанию), опциональная дедупликация |
| Папки | Создание, иерархия, перемещение между папками и бакетами |
| Файлы | Загрузка (multipart, лимит 100 MB), скачивание, перемещение, soft delete |
| Шаринг | Публичные ссылки с токеном, опциональные срок действия и лимит скачиваний |
| Безопасность | Валидация Content-Type и расширений, блокировка опасных типов (.php, .exe, .sh), rate limit ~100 req/min |

Swagger UI доступен по адресу `/swagger` для интерактивного тестирования API.

---

## Требования

- **Docker** и **Docker Compose** (v2+)
- Порты `80`, `8080`, `5433` должны быть свободны на хосте

---

## Быстрый старт (запуск для команды)

### Шаг 1: Создать и настроить `.env`

См. подробную инструкцию: [Настройка .env](#настройка-env).

### Шаг 2: Запустить стек

```bash
docker compose up -d
```

### Шаг 3: Подождать 15–20 секунд

Docker соберёт образы (при первом запуске) и поднимет PostgreSQL, бэкенд и фронтенд. Миграции применятся автоматически.

### Шаг 4: Открыть приложение

| Сервис | URL | Описание |
|--------|-----|----------|
| **Фронтенд (веб-интерфейс)** | http://localhost | SPA для работы с бакетами и файлами |
| **Swagger (документация API)** | http://localhost:8080/swagger | Интерактивная документация |
| **Health check** | http://localhost:8080/health | Проверка работоспособности API |

---

## Архитектура проекта

### Обзор

S3 Storage Service — микросервисная система из трёх слоёв:

1. **Frontend** (Vanilla JS SPA) — веб-интерфейс для пользователя
2. **Backend** (C++ Drogon) — REST API, бизнес-логика, работа с файлами
3. **Data** — PostgreSQL (метаданные) и файловая система (тела файлов)

Сервис рассчитан на работу за API Gateway: проверка сессий и CSRF выполняется в Gateway, S3 доверяет заголовку `X-User-Id`.

---

### Архитектурная диаграмма (высокий уровень)

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              КЛИЕНТ (браузер)                                        │
│                         http://localhost (порт 80)                                   │
└───────────────────────────────────┬──────────────────────────────────────────────────┘
                                    │ HTTP
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│  FRONTEND CONTAINER (Nginx)                                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │  SPA: index.html → main.js → BucketList, FileList, Breadcrumb, Modals            │ │
│  │  State: store.js    API: api/s3.js → api/client.js                                │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────┬──────────────────────────────────────────────────┘
                                    │ X-User-Id, X-Request-Id
                                    │ HTTP (REST)
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│  S3-SERVICE CONTAINER (C++ Drogon, порт 8080)                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │  Filters: GatewayAuth → CORS → RateLimit                                          │ │
│  │  Controllers: FilesController, HealthController, SwaggerController                 │ │
│  │  Services: Bucket, File, Storage, Share, Database, Security, Cleanup, Dedup         │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
└───────────────┬───────────────────────────────┬──────────────────────────────────────┘
                │ SQL                            │ read/write
                ▼                                ▼
┌───────────────────────────────┐    ┌───────────────────────────────────────────────────┐
│  POSTGRES CONTAINER (5433)    │    │  VOLUME: /opt/storage                               │
│  ┌─────────────────────────┐ │    │  users/{user_id}/buckets/{bucket_id}/files/{key}   │
│  │ buckets, files,         │ │    │  Файлы хранятся на диске, путь — в поле            │
│  │ shared_links            │ │    │  storage_key таблицы files                          │
│  └─────────────────────────┘ │    └───────────────────────────────────────────────────┘
└───────────────────────────────┘
```

---

### Поток HTTP-запроса (детально)

```
  [Browser]                    [s3-service]
      │                             │
      │  GET /files/buckets/list     │
      │  X-User-Id: uuid             │
      ├─────────────────────────────►│
      │                             │
      │                      ┌───────┴───────┐
      │                      │ 1. GatewayAuth │  Проверка X-User-Id (UUID)
      │                      │     Filter      │  Нет → 401
      │                      └───────┬───────┘
      │                              │
      │                      ┌───────┴───────┐
      │                      │ 2. CORS Filter  │  Access-Control-* заголовки
      │                      └───────┬───────┘
      │                              │
      │                      ┌───────┴───────┐
      │                      │ 3. RateLimit   │  429 при превышении лимита
      │                      │     Filter     │
      │                      └───────┬───────┘
      │                              │
      │                      ┌───────┴───────┐
      │                      │ FilesController│  listBuckets(req)
      │                      │ .listBuckets   │
      │                      └───────┬───────┘
      │                              │
      │                      ┌───────┴───────┐
      │                      │ BucketService │  SELECT FROM buckets
      │                      │ .listBuckets  │  WHERE user_id=? AND deleted_at IS NULL
      │                      └───────┬───────┘
      │                              │
      │                      ┌───────┴───────┐
      │                      │DatabaseService│  DbClient → PostgreSQL
      │                      └───────┬───────┘
      │                              │
      │  {"success":true,"data":[...]}│
      │◄─────────────────────────────┤
      │                             │
```

Исключение: `GET /files/shared/{token}` и `GET /health` проходят **без** GatewayAuth (публичный доступ).

---

### Схема данных и хранилища

**PostgreSQL (метаданные):**

```
  buckets                    files                      shared_links
  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
  │ id (UUID)        │◄─────│ bucket_id (FK)   │      │ id                │
  │ user_id          │      │ id (UUID)         │◄─────│ file_id (FK)      │
  │ name             │      │ user_id           │      │ user_id           │
  │ storage_used     │      │ parent_folder_id  │      │ token (UNIQUE)    │
  │ storage_limit    │      │ name              │      │ expires_at        │
  │ deleted_at       │      │ storage_key ──────┼──┐   │ max_downloads     │
  └──────────────────┘      │ size, mime_type   │  │   └──────────────────┘
                            │ is_folder        │  │
                            │ deleted_at       │  │   Путь на диске:
                            └──────────────────┘  │   {base}/users/{user_id}/
                                                   │   buckets/{bucket_id}/
                                                   │   files/{storage_key}
                                                   ▼
                                            ┌─────────────────────────────┐
                                            │ /opt/storage/                │
                                            │   users/                     │
                                            │     {user_id}/               │
                                            │       buckets/               │
                                            │         {bucket_id}/         │
                                            │           files/             │
                                            │             {storage_key}    │
                                            └─────────────────────────────┘
```

**Soft delete:** при удалении запись помечается `deleted_at = NOW()`. Через 7 дней CleanupService физически удаляет файлы и записи.

---

### Docker-инфраструктура

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         docker compose up                                        │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
           ▼                        ▼                        ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  frontend           │  │  s3-service          │  │  postgres            │
│  (порт 80)          │  │  (порт 8080)         │  │  (порт 5433)          │
├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤
│  Nginx Alpine        │  │  Ubuntu + C++ bin   │  │  postgres:15-alpine │
│  Статика из dist/   │  │  Drogon HTTP server │  │  Init: migrations/   │
│  VITE_API_URL       │  │  DB_HOST=postgres    │  │  Volume: postgres_   │
│  (build-time)       │  │  STORAGE=/opt/storage│  │    data             │
└──────────┬──────────┘  └──────────┬──────────┘  └──────────┬──────────┘
           │                         │                        │
           │  HTTP                   │  SQL                    │
           └─────────────────────────┼─────────────────────────┘
                                    │
                           internal network
                           (hostname: postgres)
```

---

### Модули бэкенда (детально)

| Модуль | Роль | Зависимости | Пример использования |
|--------|------|-------------|------------------------|
| **FilesController** | Обработка 14 эндпоинтов: бакеты, папки, файлы, upload/download, move, delete, share | BucketService, FileService, StorageService, ShareService, SecurityService, DedupService | `createBucket` → BucketService.createBucket |
| **HealthController** | GET /health — проверка живучести | — | Мониторинг, load balancer |
| **SwaggerController** | GET /swagger, /swagger.json — OpenAPI | — | Документация API |
| **GatewayAuthFilter** | Проверка X-User-Id (UUID), 401 при отсутствии | — | На всех /files/* кроме shared |
| **CORSFilter** | Access-Control-Allow-* для кросс-доменных запросов | — | На всех ответах |
| **RateLimitFilter** | ~100 req/min на X-User-Id или IP, 429 при превышении | — | Защита от DDoS |
| **BucketService** | create, list, checkQuota, deleteBucket | DatabaseService, StorageService, UUIDGenerator | Контроллер вызывает при create/list/delete |
| **FileService** | createFolder, listFiles, moveFile, deleteFile | DatabaseService | Контроллер при folders/create, list, move, delete |
| **StorageService** | generateStorageKey, writeFile, readFile, deleteFile, ensureDirectory | — | BucketService, FileService, ShareService, CleanupService |
| **ShareService** | createSharedLink, getFileByToken | DatabaseService, StorageService | Контроллер при share/create и shared/{token} |
| **DatabaseService** | getClient, execSqlSync/Async, newTransaction | Drogon ORM, config.json | Все сервисы, работающие с БД |
| **SecurityService** | validateUploadFile (Content-Type whitelist, extension blacklist) | — | FilesController.upload |
| **CleanupService** | cleanupFilesWithDeletedMark (cron раз в час) | DatabaseService, StorageService | main.cc: runEvery(3600) |
| **DedupService** | deduplicateBucket (stub) | DatabaseService | POST /files/buckets/{id}/deduplicate |
| **models/** | Bucket, File, SharedLink — структуры данных | — | Сервисы возвращают объекты моделей |
| **utils/** | Logger, ResponseHelper, UUIDGenerator, HealthCheck, Metrics | — | Везде |

---

### Модули фронтенда (детально)

| Модуль | Роль | Зависимости |
|--------|------|-------------|
| **main.js** | Инициализация: layout, подписка на store, инициализация модалок, обработчики кнопок | store, BucketList, FileList, Breadcrumb, Modals |
| **store.js** | Глобальное состояние: userId, buckets, files, selectedBucketId, currentFolderId, loading, error. Pub/sub: subscribe, setState | — |
| **api/client.js** | HTTP: добавление X-User-Id, X-Request-Id, парсинг {success, data/error}, обработка 401, binary | config.API_BASE_URL |
| **api/s3.js** | Обёртки: listBuckets, createBucket, listFiles, uploadFile, downloadFile, moveFile, deleteFile, createShareLink, getSharedFile | client |
| **BucketList** | Рендер списка бакетов, create/delete, drag-sort, выбор | store, api/s3 |
| **FileList** | Таблица файлов/папок, download/share/move/delete, drag | store, api/s3 |
| **Breadcrumb** | Навигация по пути папок | store |
| **Modals** | Окна: создать бакет/папку, загрузка, удаление, шаринг, move | store, api/s3 |

---

### Взаимодействие сервисов (диаграмма)

```
                    ┌─────────────────┐
                    │ FilesController  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ BucketService   │ │ FileService      │ │ ShareService     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         │    ┌──────────────┴──────────────┐    │
         │    │                             │    │
         ▼    ▼                             ▼    ▼
┌─────────────────┐                 ┌─────────────────┐
│ DatabaseService │                 │ StorageService   │
└────────┬────────┘                 └────────┬────────┘
         │                                   │
         ▼                                   ▼
┌─────────────────┐                 ┌─────────────────┐
│   PostgreSQL     │                 │  /opt/storage    │
└─────────────────┘                 └─────────────────┘

CleanupService (таймер) ──► DatabaseService ──► StorageService (удаление файлов)
```

---

### Сценарий: загрузка файла

1. Frontend: `Modals` → `api/s3.uploadFile(formData)` → `client.request(POST, /files/upload, formData)`
2. Backend: Filters → FilesController.upload
3. FilesController: SecurityService.validateUploadFile (Content-Type, расширение)
4. FilesController: BucketService.checkQuota (квота бакета)
5. StorageService: generateStorageKey, ensureDirectory, writeFile (сначала на диск)
6. DatabaseService: INSERT INTO files (storage_key, ...)
7. При ошибке после записи на диск: удалить файл, откатить транзакцию
8. Response: `{"success": true, "data": {...}}`

---

## Настройка .env

Файл `.env` содержит конфигурацию для Docker Compose. Без него приложение не запустится.

### Зачем нужен .env

- Docker Compose читает переменные из `.env` и подставляет их в контейнеры
- Пароль БД (`DB_PASSWORD`) обязателен — без него PostgreSQL не инициализируется
- Файл `.env` **не коммитится** в Git (в `.gitignore`) — в репозитории есть только шаблон `.env.example`

---

### Шаг 1: Создать файл .env из шаблона

В корне проекта лежит `.env.example` — копируйте его в `.env`.

**Linux / macOS (терминал):**
```bash
# Перейдите в корень проекта
cd s3-storage   # или cd backend/s3-storage (если в репо AIS)

# Скрипт создаст .env, если его ещё нет
./scripts/setup.sh
```

**Windows (PowerShell):**
```powershell
cd s3-storage
Copy-Item .env.example .env
```

**Windows (CMD):**
```cmd
cd s3-storage
copy .env.example .env
```

**Вручную:** скопируйте файл `.env.example` и переименуйте копию в `.env`.

---

### Шаг 2: Открыть .env в редакторе

Откройте файл `.env` (он должен быть в корне проекта, рядом с `docker-compose.yml`).

---

### Шаг 3: Обязательно задать DB_PASSWORD

В `.env` найдите строку:
```env
DB_PASSWORD=
```

Замените на любой пароль, например:
```env
DB_PASSWORD=my_secure_password_123
```

**Требования к паролю:**
- Не оставляйте пустым — иначе PostgreSQL не запустится
- Лучше использовать буквы, цифры, спецсимволы
- Для локальной разработки подойдёт простой пароль вроде `secret` или `dev123`

---

### Полное содержимое .env (пример)

После настройки файл может выглядеть так:

```env
# База данных
# DB_HOST=postgres — имя сервиса в docker-compose (не меняйте при запуске через compose)
DB_HOST=postgres
DB_PORT=5432
DB_NAME=s3storage
DB_USER=s3user
DB_PASSWORD=my_secure_password_123

# Путь к хранилищу файлов внутри контейнера (обычно не меняется)
STORAGE_BASE_PATH=/opt/storage

# URL API для фронтенда — подставляется при сборке образа
# По умолчанию http://localhost:8080 (если не задано)
# Раскомментируйте и измените для деплоя на другой хост
# VITE_API_URL=http://localhost:8080
```

---

### Описание переменных

| Переменная | Назначение | Когда менять |
|------------|------------|--------------|
| `DB_HOST` | Хост PostgreSQL. Для `docker compose` — всегда `postgres` | Для локального dev с внешней БД — `localhost` |
| `DB_PORT` | Порт PostgreSQL **внутри** Docker-сети | Обычно `5432`, не трогайте |
| `DB_NAME` | Имя базы данных | По умолчанию `s3storage` |
| `DB_USER` | Пользователь PostgreSQL | Должен совпадать с `POSTGRES_USER` в compose |
| `DB_PASSWORD` | **Пароль** — обязательно задать | Любой надёжный пароль |
| `STORAGE_BASE_PATH` | Корневая директория для загруженных файлов | Обычно `/opt/storage` |
| `VITE_API_URL` | URL бэкенда для фронтенда | Меняйте при деплое (например, `https://api.example.com`) |
| `PRODUCTION` | `true` или `1` — отключает Swagger (для production) | По умолчанию не задана, Swagger включён |

---

### Важно

1. **Не коммитьте `.env`** — в нём пароли и секреты. Файл в `.gitignore`.
2. **Первый запуск** — Docker создаёт пользователя и БД из переменных. Если потом поменяете `DB_USER` или `DB_PASSWORD`, выполните `docker compose down -v` и заново `docker compose up -d` (данные БД и файлы будут удалены).
3. **VITE_API_URL** — значение зашивается в фронтенд **при сборке** образа. Чтобы изменить URL API, поменяйте переменную в `.env` и выполните `docker compose up -d --build`.

---

### Проверка

Перед запуском убедитесь:
- Файл `.env` существует в корне проекта
- В нём есть строка `DB_PASSWORD=ваш_пароль` (не пустая)
- Нет лишних пробелов вокруг `=` (правильно: `DB_PASSWORD=secret`, неправильно: `DB_PASSWORD = secret`)

---

## Порты

| Сервис | Порт хоста | Внутри контейнера |
|--------|------------|-------------------|
| Frontend (Nginx) | 80 | 80 |
| S3 API (бэкенд) | 8080 | 8080 |
| PostgreSQL | 5433 | 5432 |

> PostgreSQL на хосте слушает `5433`, чтобы не конфликтовать с локальной установкой PostgreSQL на `5432`.

---

## Переменные окружения

Краткая справочная таблица. Подробная инструкция по созданию `.env` — в разделе [Настройка .env](#настройка-env).

| Переменная | Описание | По умолчанию | Обязательна |
|------------|----------|--------------|-------------|
| `DB_HOST` | Хост PostgreSQL | `postgres` | — |
| `DB_PORT` | Порт PostgreSQL (внутри сети Docker) | `5432` | — |
| `DB_NAME` | Имя базы данных | `s3storage` | — |
| `DB_USER` | Пользователь PostgreSQL | `s3user` | — |
| `DB_PASSWORD` | Пароль PostgreSQL | — | **Да** |
| `STORAGE_BASE_PATH` | Корень хранилища файлов | `/opt/storage` | — |
| `VITE_API_URL` | URL API для фронтенда (при сборке) | `http://localhost:8080` | — |

Если API доступен по другому адресу (например, при деплое), измените `VITE_API_URL` **перед** `docker compose up` — значение подставится в фронтенд при сборке.

---

## Управление Docker

```bash
# Запуск в фоне
docker compose up -d

# Просмотр логов
docker compose logs -f

# Остановка
docker compose down

# Остановка и удаление volumes (данные БД и файлы будут удалены)
docker compose down -v

# Пересборка после изменений кода
docker compose up -d --build
```

---

## Хранение данных

При запуске `docker compose up` данные сохраняются в **Docker volumes**. Они не теряются при перезапуске контейнеров.

### Где хранятся данные

| Данные | Volume | Путь в контейнере | Описание |
|--------|--------|-------------------|----------|
| **PostgreSQL** (бакеты, файлы, ссылки — метаданные) | `postgres_data` | `/var/lib/postgresql/data` | Таблицы `buckets`, `files`, `shared_links` |
| **Файлы** (тела загруженных файлов) | `s3_storage` | `/opt/storage` | Структура: `users/{user_id}/buckets/{bucket_id}/files/{storage_key}` |

Оба volumes — **named volumes**. Docker управляет ими и сохраняет данные между перезапусками.

### Расположение на хосте

На **Linux** volumes лежат в:
```
/var/lib/docker/volumes/<проект>_postgres_data/_data
/var/lib/docker/volumes/<проект>_s3_storage/_data
```

Имя проекта — обычно имя папки с `docker-compose.yml` (например, `s3storage` или `ais-backend-s3-storage`).

На **macOS/Windows** (Docker Desktop) volumes хранятся внутри виртуальной машины Docker, прямого доступа к ним нет.

Узнать точный путь:
```bash
docker volume inspect <проект>_postgres_data
docker volume inspect <проект>_s3_storage
```

### Удаление всех данных

```bash
docker compose down -v
```

Флаг `-v` удаляет volumes — все данные БД и загруженные файлы будут удалены. Используйте для «чистого» запуска.

---

## Структура проекта

```
s3-storage/
├── docker-compose.yml      # Оркестрация postgres, s3-service, frontend
├── .env.example            # Шаблон переменных окружения
├── migrations/             # SQL-миграции (применяются при первом запуске PostgreSQL)
│   └── 001_init.sql
│
├── frontend/               # SPA (Vanilla JS + Vite)
│   ├── src/
│   │   ├── components/     # BucketList, FileList, Modals и др.
│   │   ├── api/            # HTTP-клиент и обёртки API
│   │   └── styles/
│   ├── index.html
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
│
├── controllers/            # HTTP-контроллеры (Drogon)
├── filters/                # GatewayAuth, CORS, RateLimit
├── services/               # Бизнес-логика (Bucket, File, Storage, Share и др.)
├── models/                 # Модели данных
├── utils/                  # Утилиты
├── config.json.template    # Шаблон конфига (пароли из env)
├── Dockerfile              # Сборка s3-service
└── scripts/
    ├── setup.sh            # Создание .env из .env.example
    └── verify-all.sh       # Полная проверка (build, тесты, integration)
```

---

## Локальная разработка (без Docker)

### Бэкенд и БД

Можно поднять только PostgreSQL через Docker, а s3-service собрать и запустить локально:

```bash
docker compose up -d postgres
# Подождать, пока postgres станет healthy

# Создать .env с DB_HOST=localhost, DB_PORT=5433
# Собрать проект (см. раздел Build ниже)
# Применить миграцию вручную
# Запустить ./build/s3-storage-service
```

### Фронтенд

```bash
cd frontend
npm install
npm run dev
```

Откроется http://localhost:5173. Убедитесь, что API доступен на http://localhost:8080.

---

## Build (C++ бэкенд без Docker)

Если нужна локальная сборка:

```bash
# Генерация config.json из шаблона (пароли из env)
envsubst < config.json.template > config.json

mkdir -p build && cd build
cmake .. -DBUILD_TESTS=ON
make

# Запуск
./s3-storage-service
```

Требования: C++17, CMake 3.14+, Drogon, libpq, PostgreSQL 15+.

---

## API

**Base URL:** `http://localhost:8080`

**Обязательный заголовок:** `X-User-Id` (UUID) — для всех запросов, кроме `/health` и `/files/shared/{token}`.

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Health check |
| GET | /swagger | Swagger UI (см. [Как включить/отключить Swagger](#swagger)) |
| POST | /files/buckets/create | Создать бакет |
| GET | /files/buckets/list | Список бакетов |
| DELETE | /files/buckets/{id} | Удалить бакет |
| POST | /files/folders/create | Создать папку |
| GET | /files/list | Список файлов/папок |
| POST | /files/upload | Загрузить файл |
| GET | /files/download | Скачать файл |
| POST | /files/move | Переместить файл/папку |
| DELETE | /files/{id} | Удалить файл/папку |
| POST | /files/share/create | Создать публичную ссылку |
| GET | /files/shared/{token} | Скачать по ссылке (без авторизации) |

Формат ответов: `{"success": true, "data": {...}}` или `{"success": false, "error": {"code": "...", "message": "..."}}`.

Подробнее: [docs/FRONTEND.md](docs/FRONTEND.md) — для фронтенд-разработчиков.

---

## Troubleshooting

### Порты заняты

```
Error: bind: address already in use
```

Проверьте, что порты 80, 8080, 5433 свободны:

```bash
# Linux
sudo lsof -i :80 -i :8080 -i :5433

# macOS
lsof -i :80 -i :8080 -i :5433
```

### Фронтенд не подключается к API

- Убедитесь, что s3-service запущен: `docker compose ps`
- Проверьте health: `curl http://localhost:8080/health`
- В демо-режиме в поле **User ID** в шапке введите UUID (например, `00000000-0000-0000-0000-000000000001`)

### Ошибка `DB_PASSWORD` или `role "s3user" does not exist`

- Убедитесь, что в `.env` задан `DB_PASSWORD`
- При первом запуске Docker создаёт пользователя и БД из переменных. Если меняли `.env` после первого `up`, выполните `docker compose down -v` и заново `docker compose up -d` (данные будут потеряны).

### Swagger

Swagger UI доступен по адресу http://localhost:8080/swagger. OpenAPI спецификация — http://localhost:8080/swagger.json.

**Включение/отключение:**

| Режим | Состояние |
|-------|-----------|
| По умолчанию (docker compose) | Swagger **включён** |
| Production | Swagger **отключён** при `PRODUCTION=true` или `PRODUCTION=1` |

**Как отключить Swagger** (например, в production):

Добавьте в `.env`:

```env
PRODUCTION=true
```

Переменная передаётся в контейнер `s3-service` через docker-compose.

**Как включить Swagger:** не задавайте `PRODUCTION` в `.env` или задайте `PRODUCTION=false`. По умолчанию Swagger уже включён. При локальной сборке можно также задать `custom_config.swagger_enabled: true` в `config.json` (генерируется из `config.json.template`).

### Swagger показывает старый placeholder UUID

Нажмите **Ctrl+Shift+R** (жёсткое обновление страницы), чтобы сбросить кэш браузера.

### Пересборка после изменений

```bash
docker compose up -d --build
```

---

## Архитектура

```
┌─────────────┐     HTTP      ┌──────────────┐     SQL       ┌──────────┐
│  Frontend   │ ───────────►  │  s3-service  │ ───────────►  │ postgres │
│  (порт 80)  │               │  (порт 8080) │               │ (5433)   │
└─────────────┘               └──────────────┘               └──────────┘
                                     │
                                     ▼
                              /opt/storage (файлы)
```

- **API Gateway** проверяет сессии (Redis) и CSRF
- **S3 Service** доверяет заголовкам `X-User-Id`, `X-User-Roles` от Gateway
- Маршрут: клиент → Nginx (TLS) → API Gateway → S3 Service

---

## Безопасность

Меры безопасности реализованы по модулям. S3 Service рассчитан на работу за API Gateway: сессии и CSRF проверяются в Gateway, S3 доверяет заголовку `X-User-Id`.

### Модель доверия

| Где проверяется | Что |
|-----------------|-----|
| **API Gateway** | Сессии (Redis), CSRF-токены, TLS |
| **S3 Service** | Только наличие и формат X-User-Id (UUID). Не проверяет сессии и CSRF |

Прямой доступ к S3 без Gateway (например, демо-режим) — только для разработки. В production S3 должен быть за Gateway.

---

### Реализация по модулям

| Модуль | Мера | Описание |
|--------|------|----------|
| **GatewayAuthFilter** | Авторизация | Требует заголовок `X-User-Id` в формате UUID. Отсутствие или неверный формат → 401. Не применяется к `/health` и `/files/shared/{token}` |
| **RateLimitFilter** | Защита от DDoS | ~100 запросов в минуту на пользователя (X-User-Id) или на IP. Превышение → 429 |
| **CORSFilter** | Cross-Origin | Заголовки Access-Control-Allow-* для кросс-доменных запросов. OPTIONS preflight обрабатывается до фильтров |
| **SecurityService** | Валидация загрузок | **Whitelist Content-Type**: допустимы image/*, application/pdf, text/plain, zip, office и др. **Blacklist расширений**: блокируются .php, .phtml, .sh, .exe, .bat, .cmd, .ps1, .com |
| **StorageService** | Имена файлов | UUID вместо предсказуемых имён. Шардирование путей: `aa/bb/uuid` для распределения нагрузки |
| **DatabaseService** | Данные | Soft delete: `deleted_at IS NULL` во всех SELECT. Изоляция по `user_id` — пользователь видит только свои бакеты и файлы |
| **ShareService** | Публичные ссылки | Токен в URL, опциональные `expiresAt` и `maxDownloads`. Скачивание без X-User-Id |
| **Config / .env** | Секреты | Пароли БД — только из переменных окружения. `config.json` генерируется из template, не коммитится |

---

### Рекомендации

- **Production:** задать `PRODUCTION=true` — отключает Swagger (документация API не должна быть публичной)
- **Swagger:** скрыт при `PRODUCTION=true` (см. [Swagger](#swagger))
- **Логирование:** не логировать пароли, токены, PII; логировать `user_id` и `request_id` для трассировки
- **Права на /opt/storage:** контейнер должен иметь доступ на запись; в Docker используется named volume

---

## Тесты

```bash
cd build
ctest
```

Полная проверка (build + unit + integration): `./scripts/verify-all.sh`

---

## Дополнительная документация

- [docs/FRONTEND.md](docs/FRONTEND.md) — для фронтенд-разработчиков (API, заголовки, примеры)
- [VERIFY.md](VERIFY.md) — пошаговая верификация сборки и деплоя
