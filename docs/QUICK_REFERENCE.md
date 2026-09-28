# Краткая памятка

## Что сделано

- Flask-приложение запускается через Gunicorn в multi-stage Docker image.
- Контейнер `web` работает от непривилегированного пользователя `app`.
- PostgreSQL 16 хранит данные в named volume.
- Сервисы соединены отдельной Docker bridge-сетью.
- PostgreSQL наружу не опубликован; приложение доступно на порту 80.
- Для обоих сервисов настроены healthcheck.
- `.env` исключён из Git и Docker build context.
- Добавлены скрипты настройки Ubuntu VM и проверки persistence.

## Запуск

```bash
cp .env.example .env
chmod 600 .env
# Заменить DB_PASSWORD в .env
docker compose up -d --build --wait
curl --fail http://localhost/health
```

Полная проверка:

```bash
./scripts/verify.sh
```

## Возможные проблемы

### `Set DB_PASSWORD in .env`

Файл `.env` отсутствует или переменная пуста. Скопируйте `.env.example` и
укажите пароль.

### Порт 80 занят

Проверьте процесс:

```bash
sudo ss -ltnp | grep ':80 '
```

Остановите конфликтующий сервис либо временно задайте `HTTP_PORT=8080` в
`.env`.

### `permission denied` для Docker socket

Пользователь ещё не применил членство в группе `docker`. Перезайдите по SSH или
выполните `newgrp docker`.

### Контейнер `web` unhealthy

Проверьте состояние базы и логи без вывода переменных окружения:

```bash
docker compose ps
docker compose logs --tail=100 db
docker compose logs --tail=100 web
```

Чаще всего причина — неверный пароль, оставшийся старый volume с другими
учётными данными или база ещё не готова.

### Пароль БД изменён, но подключение не работает

PostgreSQL применяет `POSTGRES_PASSWORD` только при первой инициализации пустого
volume. Для сохранения данных верните прежний пароль. В тестовой среде, если
данные не нужны, можно пересоздать volume командой
`docker compose down --volumes`.

### После `down` данные исчезли

Вероятно, использовался флаг `--volumes`. Обычный `docker compose down` named
volume не удаляет.

### VM не выходит в интернет

Проверьте `ip route`, `/etc/resolv.conf` и `getent hosts github.com`. У VM должны
быть default route и DNS-сервер. В локальном гипервизоре выберите NAT/shared
network.

### SSH перестал принимать пароль

Это ожидаемо после hardening. Вход выполняется только приватным ключом:

```bash
ssh -i ~/.ssh/devops_deployer deployer@VM_IP
```

Перед закрытием начальной административной сессии всегда проверяйте новый вход
в отдельном терминале.

### UFW активен, но Docker-порт ведёт себя неожиданно

Docker управляет собственными правилами netfilter. Не публикуйте лишние порты в
Compose; в этом проекте наружу опубликован только HTTP. Порт PostgreSQL должен
оставаться доступным исключительно во внутренней сети `backend`.
