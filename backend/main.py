import os
from datetime import datetime
from typing import List, Optional

import psycopg2
from fastapi import FastAPI, HTTPException
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

app = FastAPI(title="Pedido Backend", version="0.1.0")

# Modelos Pydantic
class PedidoCreate(BaseModel):
    cliente: str
    producto: str
    cantidad: int
    precio_unitario: float
    observaciones: Optional[str] = None

class PedidoResponse(BaseModel):
    id: int
    cliente: str
    producto: str
    cantidad: int
    precio_unitario: float
    total: float
    observaciones: Optional[str]
    fecha_creacion: datetime
    estado: str

def get_db_conn():
    host = os.getenv("DB_HOST", "db-postgresql")
    port = int(os.getenv("DB_PORT", "5432"))
    db = os.getenv("DB_NAME", "pedido")
    user = os.getenv("DB_USER", "pedido_user")
    pwd = os.getenv("DB_PASSWORD", "pedido_password")
    return psycopg2.connect(host=host, port=port, dbname=db, user=user, password=pwd)

def init_db():
    """Inicializar la tabla de pedidos si no existe"""
    try:
        with get_db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS pedidos (
                        id SERIAL PRIMARY KEY,
                        cliente VARCHAR(100) NOT NULL,
                        producto VARCHAR(100) NOT NULL,
                        cantidad INTEGER NOT NULL,
                        precio_unitario DECIMAL(10,2) NOT NULL,
                        total DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
                        observaciones TEXT,
                        fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        estado VARCHAR(20) DEFAULT 'pendiente'
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

@app.post("/api/pedidos", response_model=PedidoResponse)
def crear_pedido(pedido: PedidoCreate):
    """Crear un nuevo pedido"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO pedidos (cliente, producto, cantidad, precio_unitario, observaciones)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id, cliente, producto, cantidad, precio_unitario, total, 
                             observaciones, fecha_creacion, estado
                """, (pedido.cliente, pedido.producto, pedido.cantidad, 
                      pedido.precio_unitario, pedido.observaciones))
                
                row = cur.fetchone()
                conn.commit()
                
                return PedidoResponse(
                    id=row['id'],
                    cliente=row['cliente'],
                    producto=row['producto'],
                    cantidad=row['cantidad'],
                    precio_unitario=float(row['precio_unitario']),
                    total=float(row['total']),
                    observaciones=row['observaciones'],
                    fecha_creacion=row['fecha_creacion'],
                    estado=row['estado']
                )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creando pedido: {str(e)}")

@app.get("/api/pedidos", response_model=List[PedidoResponse])
def listar_pedidos():
    """Listar todos los pedidos"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, cliente, producto, cantidad, precio_unitario, total,
                           observaciones, fecha_creacion, estado
                    FROM pedidos
                    ORDER BY fecha_creacion DESC
                """)
                
                rows = cur.fetchall()
                return [PedidoResponse(
                    id=row['id'],
                    cliente=row['cliente'],
                    producto=row['producto'],
                    cantidad=row['cantidad'],
                    precio_unitario=float(row['precio_unitario']),
                    total=float(row['total']),
                    observaciones=row['observaciones'],
                    fecha_creacion=row['fecha_creacion'],
                    estado=row['estado']
                ) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listando pedidos: {str(e)}")

@app.get("/api/pedidos/{pedido_id}", response_model=PedidoResponse)
def obtener_pedido(pedido_id: int):
    """Obtener un pedido específico por ID"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, cliente, producto, cantidad, precio_unitario, total,
                           observaciones, fecha_creacion, estado
                    FROM pedidos
                    WHERE id = %s
                """, (pedido_id,))
                
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=404, detail="Pedido no encontrado")
                
                return PedidoResponse(
                    id=row['id'],
                    cliente=row['cliente'],
                    producto=row['producto'],
                    cantidad=row['cantidad'],
                    precio_unitario=float(row['precio_unitario']),
                    total=float(row['total']),
                    observaciones=row['observaciones'],
                    fecha_creacion=row['fecha_creacion'],
                    estado=row['estado']
                )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo pedido: {str(e)}")

@app.get("/api/stats")
def estadisticas():
    """Obtener estadísticas de pedidos"""
    try:
        with get_db_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Total de pedidos
                cur.execute("SELECT COUNT(*) as total_pedidos FROM pedidos")
                total_pedidos = cur.fetchone()['total_pedidos']
                
                # Valor total de pedidos
                cur.execute("SELECT COALESCE(SUM(total), 0) as valor_total FROM pedidos")
                valor_total = cur.fetchone()['valor_total']
                
                # Pedidos por estado
                cur.execute("""
                    SELECT estado, COUNT(*) as cantidad 
                    FROM pedidos 
                    GROUP BY estado
                """)
                pedidos_por_estado = {row['estado']: row['cantidad'] for row in cur.fetchall()}
                
                return {
                    "total_pedidos": total_pedidos,
                    "valor_total": float(valor_total),
                    "pedidos_por_estado": pedidos_por_estado,
                    "fecha_consulta": datetime.now().isoformat()
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo estadísticas: {str(e)}")
