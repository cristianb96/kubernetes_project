import os

import psycopg2
from fastapi import FastAPI, HTTPException
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

app = FastAPI(title="Pedido Backend", version="0.1.0")

# Modelo simple para pedidos
class PedidoCreate(BaseModel):
    cliente: str
    producto: str
    cantidad: int
    precio: float

def get_db_conn():
    host = os.getenv("DB_HOST", "db-postgresql")
    port = int(os.getenv("DB_PORT", "5432"))
    db = os.getenv("DB_NAME", "pedido")
    user = os.getenv("DB_USER", "pedido_user")
    pwd = os.getenv("DB_PASSWORD", "pedido_password")
    return psycopg2.connect(host=host, port=port, dbname=db, user=user, password=pwd)

def init_db():
    """Crear tabla simple de pedidos"""
    try:
        with get_db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS pedidos (
                        id SERIAL PRIMARY KEY,
                        cliente VARCHAR(100) NOT NULL,
                        producto VARCHAR(100) NOT NULL,
                        cantidad INTEGER NOT NULL,
                        precio DECIMAL(10,2) NOT NULL,
                        total DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio) STORED,
                        fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                """)
                conn.commit()
    except Exception as e:
        print(f"Error inicializando DB: {e}")

# Inicializar la base de datos al arrancar
init_db()

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

@app.post("/api/pedidos")
def crear_pedido(pedido: PedidoCreate):
    """Crear un nuevo pedido - NUEVO ENDPOINT"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO pedidos (cliente, producto, cantidad, precio)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, cliente, producto, cantidad, precio, total, fecha_creacion
                """, (pedido.cliente, pedido.producto, pedido.cantidad, pedido.precio))
                
                row = cur.fetchone()
                conn.commit()
                
                return {
                    "id": row['id'],
                    "cliente": row['cliente'],
                    "producto": row['producto'],
                    "cantidad": row['cantidad'],
                    "precio": float(row['precio']),
                    "total": float(row['total']),
                    "fecha_creacion": row['fecha_creacion'].isoformat(),
                    "mensaje": "Pedido creado exitosamente"
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creando pedido: {str(e)}")

@app.get("/api/pedidos")
def listar_pedidos():
    """Listar todos los pedidos"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, cliente, producto, cantidad, precio, total, fecha_creacion
                    FROM pedidos
                    ORDER BY fecha_creacion DESC
                """)
                
                rows = cur.fetchall()
                return [{
                    "id": row['id'],
                    "cliente": row['cliente'],
                    "producto": row['producto'],
                    "cantidad": row['cantidad'],
                    "precio": float(row['precio']),
                    "total": float(row['total']),
                    "fecha_creacion": row['fecha_creacion'].isoformat()
                } for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listando pedidos: {str(e)}")