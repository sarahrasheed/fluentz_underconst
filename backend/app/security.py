import os, hashlib
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext
from jose import jwt

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

JWT_SECRET = os.getenv("JWT_SECRET", "CHANGE_ME")
OTP_SECRET = os.getenv("OTP_SECRET", "CHANGE_ME_TOO")
JWT_ALG = "HS256"

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)

def create_access_token(user_id: int, role: str, minutes: int = 120) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=minutes)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)

def generate_otp() -> str:
    import secrets
    return f"{secrets.randbelow(1_000_000):06d}"

def otp_hash(user_id: int, otp: str) -> str:
    raw = f"{user_id}:{otp}:{OTP_SECRET}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()
