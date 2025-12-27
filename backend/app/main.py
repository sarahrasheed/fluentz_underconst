from fastapi import FastAPI
from .db import test_db_connection

app = FastAPI(title="Fluentz API")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/db-test")
def db_test():
    return {"status": test_db_connection()}