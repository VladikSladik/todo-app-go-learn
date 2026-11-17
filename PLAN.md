# Подготовка Todo API на Go

Ориентир — ТЗ «ToDo List» из части 3.2 курса. Оно требует PostgreSQL, миграции, конфигурацию через переменные окружения, Docker Compose и Makefile. Имена файлов, порт 5433 и версии образов ниже выбраны для локальной разработки.

## Что установить на Mac

| Когда | Что понадобится | Как проверить |
|---|---|---|
| До запуска базы | Docker Desktop для Mac с Apple Silicon. Docker Compose входит в комплект. Открой Docker Desktop после установки. | `docker version` показывает Client и Server, `docker compose version` выводит версию |
| Для истории проекта | Git. Он уже доступен на этом Mac. | `git --version` |
| До первого Go-кода | Go SDK. Сначала проверь SDK из своего проекта go-learn. | `go version` в терминале проекта |
| Для команд Makefile | Make. На macOS доступен через Xcode Command Line Tools. | `make --version` |

Ссылки для установки: [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/), [Go для macOS](https://go.dev/dl/). Если отсутствуют Git или Make, выполни `xcode-select --install`.

Репозиторий курса уже скачан в соседнюю папку. Образы PostgreSQL и migrate Docker скачает при первом запуске. Клиент psql входит в образ PostgreSQL. Для этапа с базой достаточно работающего Docker Desktop и доступа в интернет для загрузки образов.

## 1. Подготовь файлы

Выполняй команды из своей папки приложения:

```sh
cd ~/Projects/todoapp
git init
mkdir -p migrations
touch compose.yaml .env .env.example .gitignore
```

## 2. Задай параметры базы

Внеси в `.env` локальные значения:

```dotenv
POSTGRES_DB=todoapp
POSTGRES_USER=todo
POSTGRES_PASSWORD=todo_local
POSTGRES_PORT=5433
```

В `.env.example` перечисли те же ключи с примерами значений. В `.gitignore` добавь строку `.env`. Проверка: `git check-ignore .env` выводит имя файла.

## 3. Опиши базу в compose.yaml

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "127.0.0.1:${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres_data:
```

С Mac база будет доступна по адресу `localhost:5433`, из другого сервиса Compose — по `db:5432`. Том postgres_data хранит данные между запусками. При первой инициализации пустого тома PostgreSQL сам создаст базу и пользователя из настроек.

## 4. Запусти PostgreSQL и подключись

```sh
docker compose up -d db
docker compose ps
docker compose exec db psql -U todo -d todoapp
```

Дождись статуса healthy перед подключением. В psql выполни `SELECT current_database(), current_user;` — ожидаются todoapp и todo. Команда `\dt` покажет, что таблиц пока нет. Выход — `\q`.

## 5. Напиши миграции

```sh
touch migrations/000001_create_users.{up,down}.sql
touch migrations/000002_create_tasks.{up,down}.sql
```

Файл up создаёт таблицу, down отменяет изменение. Сначала создай users, затем tasks, поскольку задача ссылается на пользователя.

- **users**: первичный ключ, обязательное ФИО длиной 3–100 символов, необязательный телефон. Если телефон задан, его общая длина 10–15 символов, первый символ плюс, остальные — цифры.
- **tasks**: первичный ключ, обязательный внешний ключ на автора, обязательный заголовок длиной 1–100, необязательное описание длиной 1–1000, обязательный булевый completed.
- **Время**: created_at выставляет БД. Для открытой задачи completed_at равен NULL, для завершённой задан и не раньше created_at. Позже приложение будет менять completed_at вместе с completed.
- **Удаление автора**: выбери поведение внешнего ключа. Для первой версии предлагается запрещать удаление автора, пока у него есть задачи. Это решение проекта, в ТЗ оно не задано.

## 6. Примени схему

Добавь в compose.yaml внутрь services рядом с db следующий сервис:

```yaml
  migrate:
    image: migrate/migrate:v4.18.3
    volumes:
      - ./migrations:/migrations:ro
    entrypoint:
      - migrate
      - -path=/migrations
      - -database=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
    profiles: ["tools"]
```

При работающей базе выполни:

```sh
docker compose run --rm migrate up
docker compose run --rm migrate version
docker compose exec db psql -U todo -d todoapp -c '\dt'
```

Ожидай версию 2 и таблицы users, tasks, schema_migrations. На пустой учебной базе проверь откат: `docker compose run --rm migrate down 1` удалит tasks, оставив users. Снова выполни команду up для миграций. Через psql проверь создание пользователя и задачи. Попытка вставить задачу с несуществующим автором должна завершиться ошибкой внешнего ключа.

## 7. Сохрани рабочие команды в Makefile

Создай Makefile в корне. Отступ перед каждой командой — символ Tab.

```makefile
.PHONY: db-up db-down db-shell migrate-up

db-up:
	docker compose up -d db

db-down:
	docker compose down

db-shell:
	docker compose exec db psql -U todo -d todoapp

migrate-up:
	docker compose run --rm migrate up
```

Проверь сохранение данных: создай учебную запись, выполни `make db-down`, затем `make db-up`, дождись healthy и найди запись через `make db-shell`. Флаг `-v` у команды down удаляет том, поэтому обычная команда остановки его не использует.

Теперь можно переходить к Go: проверить `go version`, создать модуль командой `go mod init todoapp` и написать первую проверку подключения приложения к базе.
