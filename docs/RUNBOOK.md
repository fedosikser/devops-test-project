# Полный алгоритм выполнения задания

Этот документ позволяет повторить работу с нуля на Ubuntu 24.04 LTS. Для VM
достаточно 2 CPU, 4 ГБ RAM и диска 20 ГБ. Сетевой режим должен позволять VM
выходить в интернет, а входящие подключения — на порты 22 и 80.

## 1. Создание VM

Подойдёт облачная VM, VirtualBox, VMware, UTM или Lima. При локальном запуске
можно пробросить порт 8081 хоста на порт 80 гостевой машины; внутри Ubuntu
приложение всё равно слушает требуемый порт 80.

После первого запуска проверьте систему:

```bash
cat /etc/os-release
ip address
ip route
getent hosts github.com
```

Ожидается Ubuntu или Debian, назначенный IP, default route и работающий DNS.

## 2. Подготовка SSH-ключа

На рабочем компьютере создайте отдельный ключ, если подходящего ещё нет:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops_deployer
scp ~/.ssh/devops_deployer.pub initial-user@VM_IP:/tmp/deployer.pub
```

Приватный файл `~/.ssh/devops_deployer` нельзя копировать в проект или VM.

## 3. Создание `deployer` и hardening VM

Скопируйте репозиторий или только `scripts/provision-vm.sh` во временное место
на VM. Затем выполните скрипт из первоначальной административной учётной записи:

```bash
sudo PUBLIC_KEY_FILE=/tmp/deployer.pub bash scripts/provision-vm.sh
```

Скрипт выполняет следующие действия:

1. создаёт пользователя `deployer`;
2. добавляет его в группы `sudo` и `docker`;
3. устанавливает публичный ключ в `authorized_keys`;
4. отключает SSH-вход по паролю и вход пользователя `root`;
5. устанавливает Docker Engine и Docker Compose plugin;
6. включает UFW с разрешёнными входящими портами 22 и 80.

Не закрывайте первую SSH-сессию до проверки второй:

```bash
ssh -i ~/.ssh/devops_deployer deployer@VM_IP
sudo -n true
docker version
sudo ufw status verbose
```

Проверьте эффективные параметры SSH:

```bash
sudo sshd -T | grep -E 'passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication'
```

Ожидаемые значения: `passwordauthentication no`,
`kbdinteractiveauthentication no`, `permitrootlogin no` и
`pubkeyauthentication yes`.

## 4. Git и ветка разработки

Исходный проект хранится в `main`. Все изменения Docker и документации делаются
в отдельной ветке:

```bash
git switch -c feature/dockerize
```

Пример истории Conventional Commits:

```text
feat: add production Docker stack
feat: automate secure VM provisioning
docs: add deployment and verification guide
docs: add container verification evidence
```

Перед отправкой изменений проверьте, что секреты не отслеживаются:

```bash
git check-ignore -v .env
git ls-files .env
git diff --check main...HEAD
```

Первая команда должна показать правило `.gitignore`, а вторая — не вывести
ничего.

## 5. Клонирование проекта на VM

Под пользователем `deployer`:

```bash
git clone https://github.com/OWNER/devops-test-project.git
cd devops-test-project
git switch feature/dockerize
```

Убедитесь, что выбрана правильная ветка:

```bash
git status --short --branch
git log --oneline -5
```

## 6. Настройка переменных окружения

Создайте локальный `.env` из безопасного шаблона:

```bash
cp .env.example .env
chmod 600 .env
```

Откройте `.env` и замените `DB_PASSWORD` на уникальный пароль. Не показывайте
его в скриншотах и не передавайте как аргумент командной строки.

Проверьте, что Compose-конфигурация валидна, не печатая итоговые значения:

```bash
docker compose config --quiet
```

## 7. Сборка и запуск

```bash
docker compose up -d --build --wait
docker compose ps
```

Оба контейнера должны иметь статус `healthy`. PostgreSQL не публикует порт на
хост, а приложение публикует `0.0.0.0:80->5000/tcp`.

Проверьте endpoints:

```bash
curl --fail http://localhost/
curl --fail http://localhost/health
curl --fail http://localhost/data
```

В `/health` ожидаются `status: healthy` и `database: connected`.

## 8. Проверка сохранения данных

```bash
curl --fail http://localhost/data
docker compose down
docker compose up -d --wait
curl --fail http://localhost/data
```

Значение `new_record.id` после перезапуска должно стать больше. Для полной
автоматической проверки используйте:

```bash
./scripts/verify.sh
```

Не добавляйте `--volumes` к `docker compose down`: эта опция удаляет данные и
делает проверку persistence бессмысленной.

## 9. Финальные проверки

```bash
docker compose ps
docker images devops-test-project-web
docker compose exec -T web id
sudo ufw status verbose
```

Команда `id` внутри `web` должна показывать непривилегированного пользователя
`app`, а не `root`.

С хоста проверьте внешний доступ:

```bash
curl --fail http://VM_IP/health
```

При локальном пробросе 8081 → 80 используйте `http://localhost:8081/health`.

## 10. Issue и Pull Request

Создайте Issue с заголовком `Task: Dockerize and Deploy the Application`, затем
отправьте обе ветки и откройте PR из `feature/dockerize` в `main`:

```bash
git push -u origin main
git push -u origin feature/dockerize
gh pr create --base main --head feature/dockerize
```

В PR укажите архитектуру, меры безопасности и фактически выполненные проверки.
Не вставляйте содержимое `.env`, токены, приватные ключи или полный вывод
`docker inspect`.

## 11. Остановка

Остановить приложение, сохранив БД:

```bash
docker compose down
```

Вернуть его в работу:

```bash
docker compose up -d --wait
```

Удаление volume допустимо только когда тестовые данные больше не нужны:

```bash
docker compose down --volumes
```
