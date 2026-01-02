from sqlalchemy import text
from app.db import engine

with engine.connect() as conn:
    print("✅ Connected to DB")
    db_name = conn.execute(text("SELECT DATABASE()")).scalar()
    print("DB:", db_name)
    tables = conn.execute(text("SHOW TABLES")).fetchall()
    print("Tables:", tables)