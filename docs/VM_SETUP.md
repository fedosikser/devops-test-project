# Развертывание на Ubuntu VM

## 1. Подготовьте ключ

На локальной машине создайте отдельную пару ключей, если её ещё нет:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops_deployer
scp ~/.ssh/devops_deployer.pub root@VM_IP:/tmp/deployer.pub
```

Не добавляйте приватный ключ, `.env` или токены в репозиторий.

## 2. Подготовьте VM

На чистой Ubuntu VM запустите скрипт из репозитория от `root`:

```bash
sudo PUBLIC_KEY_FILE=/tmp/deployer.pub bash scripts/provision-vm.sh
```

Скрипт создаёт пользователя `deployer`, устанавливает Docker Engine и Compose,
оставляет во входящем файрволе только SSH и HTTP, отключает вход по паролю и
вход для `root`. Перед закрытием текущей root-сессии проверьте второй терминал:

```bash
ssh -i ~/.ssh/devops_deployer deployer@VM_IP
sudo -v
docker version
```

## 3. Разверните приложение

```bash
git clone https://github.com/OWNER/devops-test-project.git
cd devops-test-project
git switch feature/dockerize
cp .env.example .env
chmod 600 .env
```

Замените `DB_PASSWORD` в `.env` на уникальный пароль. Затем:

```bash
docker compose up -d --build --wait
docker compose ps
curl --fail http://localhost/health
```

Приложение будет доступно по адресу `http://VM_IP/`.

## 4. Проверьте сохранение данных

```bash
curl --fail http://localhost/data
docker compose down
docker compose up -d --wait
curl --fail http://localhost/data
```

Идентификатор `new_record.id` после перезапуска должен увеличиться. Команда
`docker compose down` сохраняет named volume; `docker compose down --volumes`
удаляет данные и для проверки persistence не используется.
