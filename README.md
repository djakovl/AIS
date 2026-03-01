# Проект по Архитектуре Информационных Систем

Микросервисная архитектура корпоративного уровня для управления учебным процессом, включающая сервисы аутентификации, управления задачами и хранения файлов.

## Обзор архитектуры

Проект реализует распределенную микросервисную архитектуру со следующими компонентами:

- **API Gateway**: Центральная маршрутизация и управление сессиями с использованием Redis
- **Сервис аутентификации**: Управление пользователями с PostgreSQL и JWT-сессиями
- **Сервис задач**: CRUD-операции для учебных задач с отслеживанием статусов
- **Сервис хранилища S3**: Управление файлами с организацией по бакетам
- **Фронтенд-приложения**: Vue.js SPA для управления задачами и файлами

### Технологический стек

| Компонент | Технология | Порт |
|-----------|-----------|------|
| Gateway | Go (net/http) | 8080 |
| Auth Service | Go (net/http) | 3000 |
| Task Service | Go (Gin) | 3003 |
| S3 Service | C++ (Drogon) | 3002 |
| PostgreSQL | 16-alpine | 5432 |
| Redis | 7.2-alpine | 6379 |
| Nginx | 1.25-alpine | 80/443 |

## Структура проекта

```
AIS/
├── backend/
│   ├── auth-service/          # Аутентификация и авторизация
│   ├── gateway/               # API Gateway с управлением сессиями
│   ├── s3-storage/           # Сервис хранения файлов (C++/Drogon)
│   └── task-service/         # Сервис управления задачами (Go/Gin)
├── frontend/
│   ├── auth-service/         # Статический HTML/JS интерфейс авторизации
│   ├── task-frontend/        # Vue.js SPA для задач
│   └── s3-storage/          # Vue.js SPA для файлов
├── infra/
│   ├── init-db.sql          # Скрипты инициализации БД
│   ├── nginx.conf           # Конфигурация Nginx
│   └── ssl/                 # TLS сертификаты
├── .github/workflows/       # CI/CD пайплайны
└── docker-compose.yml       # Оркестрация сервисов
```

## Основные возможности

### Аутентификация
- Сессионная аутентификация с хранением в Redis
- CSRF-защита для всех операций изменения состояния
- Ролевая модель доступа (RBAC)
- Безопасное хеширование паролей с pgcrypto

### Управление задачами
- Иерархическая структура задач с родительско-дочерними связями
- Отслеживание статусов (ожидание, в работе, завершено, отменено)
- Уровни приоритета (низкий, средний, высокий, срочный)
- Полнотекстовый поиск и фильтрация

### Хранилище файлов
- Организация файлов по бакетам
- Квота 10GB на бакет
- Публичные/приватные файлы с временными ссылками
- Мягкое удаление с хранением 7 дней

## API эндпоинты

### Сервис аутентификации

```
POST   /auth/register    # Регистрация пользователя
POST   /auth/login       # Вход пользователя
POST   /auth/logout      # Выход пользователя
GET    /auth/profile     # Получение профиля
```

### Сервис задач

```
GET    /tasks            # Список задач с пагинацией
GET    /tasks/:id        # Получение задачи по ID
POST   /tasks            # Создание задачи
PUT    /tasks/:id        # Обновление задачи
DELETE /tasks/:id        # Удаление задачи
GET    /statuses         # Доступные статусы
GET    /priorities       # Доступные приоритеты
```

### Сервис хранилища S3

```
GET    /buckets                      # Список бакетов пользователя
POST   /buckets                      # Создание бакета
GET    /buckets/:id/files           # Список файлов в бакете
POST   /buckets/:id/files           # Загрузка файла
DELETE /files/:id                    # Удаление файла
GET    /files/:id/download          # Скачивание файла
POST   /files/:id/share             # Создание публичной ссылки
```

## Развертывание

### Требования

- Docker 20.10+
- Docker Compose 2.0+
- Git

### Быстрый старт

1. Клонирование репозитория:
```bash
git clone https://github.com/djakovl/AIS.git
cd AIS
git checkout prod
```

2. Настройка окружения:
```bash
cp .env.example .env
# Отредактировать .env согласно вашей конфигурации
```

3. Генерация SSL сертификатов (или использование существующих):
```bash
# Сертификаты должны находиться в infra/ssl/
ls infra/ssl/
# cert.pem
# key.pem
```

4. Запуск сервисов:
```bash
docker compose up -d --build
```

5. Проверка развертывания:
```bash
curl -k https://localhost:8037/health
```

### Точки доступа

- Auth App: `https://185.135.82.161:8037/auth-app/`
- Task App: `https://185.135.82.161:8037/task-app/`
- S3 App: `https://185.135.82.161:8037/s3-app/`
- Health Check: `https://185.135.82.161:8037/health`

## Разработка

### Схема базы данных

Система использует две схемы PostgreSQL:

#### auth.users
```sql
id            UUID PRIMARY KEY
email         VARCHAR(255) UNIQUE
password_hash VARCHAR(255)
username      VARCHAR(100)
roles         TEXT DEFAULT 'user'
is_active     BOOLEAN DEFAULT true
created_at    TIMESTAMP
updated_at    TIMESTAMP
```

#### tasks.tasks
```sql
id              UUID PRIMARY KEY
user_id         UUID
parent_task_id  UUID (nullable)
title           VARCHAR(255)
description     TEXT
status_id       INT REFERENCES tasks.statuses
priority_id     INT REFERENCES tasks.priorities
due_date        TIMESTAMP
completed_at    TIMESTAMP
is_completed    BOOLEAN
order_index     INT
tags            TEXT[]
created_at      TIMESTAMP
updated_at      TIMESTAMP
```

### Запуск тестов

```bash
# Тесты бэкенда
cd backend/auth-service && go test ./...
cd backend/gateway && go test ./...
cd backend/task-service && go test ./...

# Тесты S3 сервиса
cd backend/s3-storage
mkdir build && cd build
cmake .. && make
ctest
```

### Пересборка отдельных сервисов

```bash
# Пересборка конкретного сервиса
docker compose up -d --build gateway

# Просмотр логов
docker logs gateway -f
```

## CI/CD пайплайн

Проект использует GitHub Actions для непрерывной интеграции и развертывания:

### CI Pipeline
- Линтинг и проверка качества кода (golangci-lint)
- Юнит-тесты с отчетами о покрытии
- Сборка Docker образов
- Автоматический запуск при push и pull request

### CD Pipeline
- SSH развертывание на продакшен сервер
- Git pull и сброс до последнего коммита
- Перезапуск сервисов с проверкой health
- Автоматический откат при ошибках
- Триггер при push в ветку `prod`

## Безопасность

- Весь HTTP трафик перенаправляется на HTTPS
- Шифрование TLS 1.2
- Валидация CSRF токенов для всех мутаций
- Сессионная аутентификация с Redis
- Rate limiting (60 запросов/с с burst 30)
- CORS защита
- Предотвращение SQL инъекций через prepared statements
- Хеширование паролей с pgcrypto

## Мониторинг

Эндпоинт проверки здоровья сервисов:
```bash
curl -k https://185.135.82.161:8037/health
```

Логи сервисов:
```bash
docker compose logs -f [service-name]
```
