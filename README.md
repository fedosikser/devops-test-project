# DevOps Test Project

Простое веб-приложение на Flask с подключением к PostgreSQL для тестирования DevOps навыков.

## 📋 Описание

Приложение предоставляет следующие endpoints:
- `GET /` - Главная страница (статус приложения)
- `GET /health` - Health check (проверка подключения к БД)
- `GET /data` - Тестовый endpoint для работы с БД

## 🚀 Локальный запуск (без Docker)

### Требования:
- Python 3.8+
- PostgreSQL 13+

### Установка:

```bash
# Создать виртуальное окружение
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

# Установить зависимости
pip install -r app/requirements.txt

# Настроить переменные окружения
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=testdb
export DB_USER=postgres
export DB_PASSWORD=secret

# Запустить приложение
python app/app.py
