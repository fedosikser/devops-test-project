from flask import Flask, jsonify
import psycopg2
import os
from datetime import datetime

app = Flask(__name__)

def get_db_connection():
    """Подключение к PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            database=os.getenv("DB_NAME", "testdb"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", "secret")
        )
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

@app.route('/')
def index():
    """Главная страница"""
    return jsonify({
        "status": "ok",
        "message": "DevOps Test Application is running!",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute('SELECT version();')
            version = cur.fetchone()[0]
            cur.close()
            conn.close()
            return jsonify({
                "status": "healthy",
                "database": "connected",
                "db_version": version
            })
        except Exception as e:
            return jsonify({
                "status": "unhealthy",
                "database": "error",
                "error": str(e)
            }), 500
    else:
        return jsonify({
            "status": "unhealthy",
            "database": "disconnected"
        }), 500

@app.route('/data', methods=['GET', 'POST'])
def data():
    """Тестовый endpoint для работы с БД"""
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database not connected"}), 500
    
    try:
        cur = conn.cursor()
        
        # Создаем таблицу если её нет
        cur.execute('''
            CREATE TABLE IF NOT EXISTS test_data (
                id SERIAL PRIMARY KEY,
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        
        # Добавляем тестовую запись
        cur.execute(
            "INSERT INTO test_data (message) VALUES (%s) RETURNING id, message, created_at",
            (f"Test message at {datetime.now().isoformat()}",)
        )
        new_record = cur.fetchone()
        conn.commit()
        
        # Получаем все записи
        cur.execute("SELECT id, message, created_at FROM test_data ORDER BY created_at DESC LIMIT 10")
        records = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return jsonify({
            "status": "success",
            "new_record": {
                "id": new_record[0],
                "message": new_record[1],
                "created_at": new_record[2].isoformat()
            },
            "total_records": len(records)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.getenv("PORT", "5000"))
    app.run(host='0.0.0.0', port=port, debug=False)