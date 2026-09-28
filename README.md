# DevOps Test Project

Контейнеризованное Flask-приложение с PostgreSQL. Стек запускается одной
командой, проверяет готовность базы перед стартом приложения и сохраняет данные
в Docker volume.

## Архитектура

- `web`: Flask под Gunicorn, непривилегированный пользователь `app`, порт 5000;
- `db`: PostgreSQL 16 Alpine с persistent volume;
- `backend`: изолированная bridge-сеть между сервисами;
- наружу опубликован только HTTP-порт приложения (по умолчанию `80`).

## Быстрый старт

Требуются Docker Engine и Docker Compose v2.

```bash
cp .env.example .env
```

Замените демонстрационное значение `DB_PASSWORD` в `.env` на стойкий локальный
пароль. Файл `.env` исключён из Git и Docker build context.

```bash
docker compose up -d --build --wait
curl --fail http://localhost/health
```

Ожидаемый статус — `healthy`, а поле `database` — `connected`.

Если порт 80 занят или требует дополнительных прав, задайте в `.env`, например,
`HTTP_PORT=8080` и используйте `http://localhost:8080`.

## Endpoints

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/` | Статус приложения |
| GET | `/health` | Проверка соединения с PostgreSQL |
| GET/POST | `/data` | Создание тестовой записи и проверка БД |

## Проверка persistence

Скрипт создаёт запись, перезапускает Compose-стек без удаления volume и
убеждается, что ID следующей записи увеличился:

```bash
./scripts/verify.sh
```

При нестандартном порте используйте, например:

```bash
BASE_URL=http://localhost:8080 ./scripts/verify.sh
```

Остановить сервисы без удаления данных:

```bash
docker compose down
```

Полностью удалить сервисы вместе с данными можно только явно:

```bash
docker compose down --volumes
```

## Развертывание на VM

Пошаговая настройка Ubuntu, пользователя `deployer`, SSH и UFW описана в
[`docs/VM_SETUP.md`](docs/VM_SETUP.md). Для воспроизводимой подготовки машины
добавлен [`scripts/provision-vm.sh`](scripts/provision-vm.sh).

Полный алгоритм от создания VM до Pull Request приведён в
[`docs/RUNBOOK.md`](docs/RUNBOOK.md), а краткое описание и типовые ошибки — в
[`docs/QUICK_REFERENCE.md`](docs/QUICK_REFERENCE.md).

## Безопасность

- контейнер приложения запускается не от `root`;
- секреты передаются через локальный `.env`, который не коммитится;
- `.dockerignore` исключает секреты и служебные файлы из build context;
- порт PostgreSQL не публикуется на хост;
- production-сервер Gunicorn запускается без Flask debug mode.
