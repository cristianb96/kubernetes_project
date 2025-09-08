from fastapi import FastAPI
import os
import psycopg2
from psycopg2.extras import RealDictCursor

app = FastAPI(title="Pedido Backend", version="0.1.0")

def get_db_conn():
    host = os.getenv("DB_HOST", "db-postgresql")
    port = int(os.getenv("DB_PORT", "5432"))
    db = os.getenv("DB_NAME", "pedido")
    user = os.getenv("DB_USER", "pedido_user")
    pwd = os.getenv("DB_PASSWORD", "pedido_password")
    return psycopg2.connect(host=host, port=port, dbname=db, user=user, password=pwd)

@app.get("/api/health")
def health():
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("SELECT 1 AS ok;")
                row = cur.fetchone()
        return {"status": "ok", "db": row["ok"]}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/api/ping")
def ping():
    return {"message": "pong"}
