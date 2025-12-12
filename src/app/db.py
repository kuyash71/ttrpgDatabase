import os
import psycopg2
from psycopg2.extras import RealDictCursor

def get_conn():
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL is not set. Create a .env file based on .env.example")
    return psycopg2.connect(db_url)

def fetch_all(query: str, params=()):
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            return cur.fetchall()

def fetch_one(query: str, params=()):
    rows = fetch_all(query, params)
    return rows[0] if rows else None

def execute(query: str, params=()):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            conn.commit()
