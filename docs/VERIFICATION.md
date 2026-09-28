# Результаты локальной проверки

Проверка выполнена на Docker Compose v5.0.2. Оба сервиса запустились и перешли
в состояние `healthy`; приложение опубликовано на порту 80, а PostgreSQL
доступен только во внутренней Docker-сети.

## Запущенные контейнеры

![docker compose ps](evidence/docker-ps.png)

## Health check

`GET /health` вернул `status: healthy` и `database: connected`.

![curl health](evidence/health.png)

## Сохранение данных

До `docker compose down` создана запись с ID 1. После повторного
`docker compose up -d --wait` следующая запись получила ID 2, что подтверждает
сохранение данных в named volume.

![persistence check](evidence/persistence.png)

## Размер образа

![docker images](evidence/images.png)

Скриншоты содержат только технический вывод тестового окружения; значения из
локального `.env` в них не выводятся.
