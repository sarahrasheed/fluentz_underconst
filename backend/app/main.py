from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, desc
from datetime import datetime, timedelta
import json
from .matching_service import get_recommendations

# NEW for stateless assessment
import os
import base64
import hmac
import hashlib
from pydantic import BaseModel

from .db import get_db
from .models import (
    User,
    EmailOtpCode,
    LanguageAssessment,
    LearnerProfile,
    UserLanguage,
    UserInterest,
    Language,
    Interest,
)
from .schemas import (
    RegisterIn, RegisterOut,
    VerifyOtpIn, ResendOtpIn,
    LoginIn, LoginOut,
    SubmitAssessmentIn,
    CompleteProfileIn,
)

from .security import (
    hash_password, verify_password,
    create_access_token,
    generate_otp, otp_hash
)
from .emailer import send_otp_email

from .cefr import harder, easier, writing_score_to_cefr
from .ai_test import make_mcq, make_writing_prompt, grade_writing


app = FastAPI(title="Fluentz API")

OTP_EXPIRE_MINUTES = 10
OTP_ATTEMPTS = 5

# =========================
# Health
# =========================
@app.get("/health")
def health():
    return {"status": "ok"}


# =========================
# Auth: Register
# =========================
@app.post("/auth/register", response_model=RegisterOut)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    existing = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role="learner",
        is_email_verified=False,
        onboarding_status="registered"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    otp = generate_otp()
    code = EmailOtpCode(
        user_id=user.id,
        otp_hash=otp_hash(int(user.id), otp),
        expires_at=datetime.utcnow() + timedelta(minutes=OTP_EXPIRE_MINUTES),
        used_at=None,
        attempts_left=OTP_ATTEMPTS
    )
    db.add(code)
    db.commit()

    send_otp_email(user.email, otp)
    return {"user_id": int(user.id), "message": "Registered. OTP sent."}


# =========================
# Auth: Resend OTP
# =========================
@app.post("/auth/resend-otp")
def resend_otp(payload: ResendOtpIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.is_email_verified:
        return {"message": "Email already verified"}

    otp = generate_otp()
    code = EmailOtpCode(
        user_id=user.id,
        otp_hash=otp_hash(int(user.id), otp),
        expires_at=datetime.utcnow() + timedelta(minutes=OTP_EXPIRE_MINUTES),
        used_at=None,
        attempts_left=OTP_ATTEMPTS
    )
    db.add(code)
    db.commit()

    send_otp_email(user.email, otp)
    return {"message": "OTP resent"}


# =========================
# Auth: Verify OTP
# =========================
@app.post("/auth/verify-otp")
def verify_otp(payload: VerifyOtpIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.is_email_verified:
        return {
            "message": "Already verified",
            "user_id": int(user.id),
            "next_step": "profile_setup"
        }

    otp_row = db.execute(
        select(EmailOtpCode)
        .where(EmailOtpCode.user_id == user.id)
        .where(EmailOtpCode.used_at.is_(None))
        .order_by(desc(EmailOtpCode.created_at), desc(EmailOtpCode.id))
        .limit(1)
    ).scalar_one_or_none()

    if not otp_row:
        raise HTTPException(status_code=400, detail="No active OTP. Resend OTP.")

    if datetime.utcnow() > otp_row.expires_at:
        raise HTTPException(status_code=400, detail="OTP expired. Resend OTP.")

    if otp_row.attempts_left <= 0:
        raise HTTPException(status_code=400, detail="Too many attempts. Resend OTP.")

    if otp_hash(int(user.id), payload.otp) != otp_row.otp_hash:
        otp_row.attempts_left -= 1
        db.commit()
        raise HTTPException(status_code=400, detail=f"Invalid OTP. Attempts left: {otp_row.attempts_left}")

    otp_row.used_at = datetime.utcnow()
    user.is_email_verified = True
    user.onboarding_status = "verified"
    db.commit()

    return {
        "message": "Email verified",
        "user_id": int(user.id),
        "next_step": "profile_setup"
    }


# =========================
# Auth: Login
# =========================
# =========================
# Auth: Login
# =========================
@app.post("/auth/login", response_model=LoginOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_email_verified:
        raise HTTPException(status_code=403, detail="Email not verified")

    token = create_access_token(int(user.id), user.role)
    return {
        "access_token": token,
        "role": user.role,
        "onboarding_status": user.onboarding_status,
        "user_id": int(user.id),   
    }

from pydantic import BaseModel

class MatchingRequest(BaseModel):
    user_id: int


@app.post("/matching/recommend")
def matching_recommend(payload: MatchingRequest, db: Session = Depends(get_db)):
    user_id = payload.user_id

    user = db.execute(
        select(User).where(User.id == user_id)
    ).scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.onboarding_status not in ("profile_completed", "assessed"):
        raise HTTPException(
            status_code=400,
            detail="User must complete profile first"
        )

    recommendations = get_recommendations(db, user_id=user_id, limit=20)

    return {
        "user_id": user_id,
        "recommended_matches": [
            {
                "id": r["user_id"],
                "name": r["full_name"],
                "age": r["age"] if r["age"] is not None else "unknown",
                "interests": r["shared_interests"],
                "score": float(r["score"]),
                "profile_picture": r["profile_photo_url"],
            }
            for r in recommendations
        ]
    }

# =========================
# (Optional) Simple assessment submit (manual)
# =========================
@app.post("/assessment/submit")
def submit_assessment(user_id: int, payload: SubmitAssessmentIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    a = LanguageAssessment(
        user_id=user.id,
        language_id=payload.language_id,
        level=payload.level,
        score=payload.score
    )
    db.add(a)
    user.onboarding_status = "assessed"
    db.commit()

    return {"message": "Assessment saved", "status": user.onboarding_status}


# =========================
# Profile: Complete
# =========================
@app.post("/profile/complete")
def complete_profile(payload: CompleteProfileIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == payload.user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # ✅ Correct flow: user must be verified first (profile BEFORE assessment)
    if user.onboarding_status not in ("verified", "profile_completed", "assessed"):
        raise HTTPException(status_code=400, detail="User must verify email first")

    # Upsert learner_profile
    lp = db.execute(select(LearnerProfile).where(LearnerProfile.user_id == user.id)).scalar_one_or_none()
    if not lp:
        lp = LearnerProfile(
            user_id=user.id,
            date_of_birth=payload.date_of_birth,
            gender=payload.gender,
            short_description=payload.short_description,
            profile_photo_url=payload.profile_photo_url
        )
        db.add(lp)
    else:
        lp.date_of_birth = payload.date_of_birth
        lp.gender = payload.gender
        lp.short_description = payload.short_description
        lp.profile_photo_url = payload.profile_photo_url

    # Reset languages/interests (MVP)
    db.query(UserLanguage).filter(UserLanguage.user_id == user.id).delete()
    db.query(UserInterest).filter(UserInterest.user_id == user.id).delete()
    db.flush()

    # Languages
    db.add(UserLanguage(user_id=user.id, language_id=payload.native_language_id, type="native"))

    for lid in payload.fluent_language_ids:
        if lid != payload.native_language_id:
            db.add(UserLanguage(user_id=user.id, language_id=lid, type="fluent"))

    for lid in payload.target_language_ids:
        if lid == payload.native_language_id:
            continue
        db.add(UserLanguage(
            user_id=user.id,
            language_id=lid,
            type="target",
            proficiency_level=None
        ))

    # Interests
    for iid in sorted(set(payload.interest_ids)):
        db.add(UserInterest(user_id=user.id, interest_id=iid))

    # ✅ Only set profile_completed if not already assessed
    if user.onboarding_status != "assessed":
        user.onboarding_status = "profile_completed"

    db.commit()
    return {"message": "Profile completed", "status": user.onboarding_status}


# =========================
# Meta
# =========================
@app.get("/meta/languages")
def list_languages(db: Session = Depends(get_db)):
    rows = db.execute(select(Language).order_by(Language.name)).scalars().all()
    return [{"id": int(r.id), "code": r.code, "name": r.name} for r in rows]


@app.get("/meta/interests")
def list_interests(db: Session = Depends(get_db)):
    rows = db.execute(select(Interest).order_by(Interest.name)).scalars().all()
    return [{"id": int(r.id), "name": r.name} for r in rows]


# ============================================================
# ✅ AI Assessment (Option 1) — STATELESS, NO SESSION TABLES
# ============================================================

MAX_CORE_QUESTIONS = 8

# Put this in your .env:
# ASSESSMENT_SECRET=some-long-random-string
ASSESSMENT_SECRET = os.getenv("ASSESSMENT_SECRET", "dev-secret-change-me")


def _b64url_encode(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


def _b64url_decode(s: str) -> bytes:
    pad = "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


def sign_json(payload: dict) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    sig = hmac.new(ASSESSMENT_SECRET.encode(), raw, hashlib.sha256).digest()
    return _b64url_encode(raw) + "." + _b64url_encode(sig)


def verify_json(token: str) -> dict:
    try:
        raw_b64, sig_b64 = token.split(".")
        raw = _b64url_decode(raw_b64)
        sig = _b64url_decode(sig_b64)
        expected = hmac.new(ASSESSMENT_SECRET.encode(), raw, hashlib.sha256).digest()
        if not hmac.compare_digest(sig, expected):
            raise ValueError("bad signature")
        return json.loads(raw.decode())
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid or tampered token")


class AiAssessmentStartIn(BaseModel):
    user_id: int
    language_id: int


class AiAssessmentAnswerIn(BaseModel):
    state_token: str
    answer_key: str
    choice: str


class AiAssessmentWritingIn(BaseModel):
    state_token: str
    text: str


@app.post("/assessment/ai/start")
def ai_assessment_start(payload: AiAssessmentStartIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == payload.user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.onboarding_status != "profile_completed":
        raise HTTPException(status_code=400, detail="User must complete profile first")

    lang = db.execute(select(Language).where(Language.id == payload.language_id)).scalar_one_or_none()
    if not lang:
        raise HTTPException(status_code=400, detail="Invalid language_id")

    estimated = "B1"
    step = 1

    q = make_mcq(lang.name, estimated)

    state_token = sign_json({
        "user_id": int(user.id),
        "language_id": int(lang.id),
        "step": step,
        "estimated": estimated,
        "phase": "mcq",
        "ts": int(datetime.utcnow().timestamp())
    })

    answer_key = sign_json({
        "user_id": int(user.id),
        "language_id": int(lang.id),
        "step": step,
        "correct": q["correct"]
    })

    return {
        "step": step,
        "type": "mcq",
        "target_cefr": estimated,
        "prompt": q["prompt"],
        "options": q["options"],
        "state_token": state_token,
        "answer_key": answer_key
    }


@app.post("/assessment/ai/answer-mcq")
def ai_assessment_answer(payload: AiAssessmentAnswerIn, db: Session = Depends(get_db)):
    state = verify_json(payload.state_token)
    key = verify_json(payload.answer_key)

    # token consistency
    if key.get("user_id") != state.get("user_id") or key.get("language_id") != state.get("language_id") or key.get("step") != state.get("step"):
        raise HTTPException(status_code=400, detail="Token mismatch")

    user_id = int(state["user_id"])
    language_id = int(state["language_id"])
    step = int(state["step"])
    estimated = str(state["estimated"])

    lang = db.execute(select(Language).where(Language.id == language_id)).scalar_one_or_none()
    if not lang:
        raise HTTPException(status_code=400, detail="Invalid language_id")

    correct = (key.get("correct") or "").strip()
    choice = (payload.choice or "").strip()

    is_correct = choice == correct
    prev_feedback = "Correct ✅" if is_correct else f"Incorrect ❌. Correct answer is {correct}."

    estimated = harder(estimated) if is_correct else easier(estimated)
    next_step = step + 1

    # done core -> writing prompt
    if next_step > MAX_CORE_QUESTIONS:
        wp = make_writing_prompt(lang.name, estimated)

        next_state_token = sign_json({
            "user_id": user_id,
            "language_id": language_id,
            "step": next_step,
            "estimated": estimated,
            "phase": "writing",
            "ts": int(datetime.utcnow().timestamp())
        })

        return {
            "done_core": True,
            "type": "writing",
            "target_cefr": estimated,
            "prompt": wp["prompt"],
            "limits": {"min_words": wp["min_words"], "max_words": wp["max_words"]},
            "prev_feedback": prev_feedback,
            "state_token": next_state_token
        }

    # otherwise next MCQ
    q = make_mcq(lang.name, estimated)

    next_state_token = sign_json({
        "user_id": user_id,
        "language_id": language_id,
        "step": next_step,
        "estimated": estimated,
        "phase": "mcq",
        "ts": int(datetime.utcnow().timestamp())
    })

    next_answer_key = sign_json({
        "user_id": user_id,
        "language_id": language_id,
        "step": next_step,
        "correct": q["correct"]
    })

    return {
        "done_core": False,
        "step": next_step,
        "type": "mcq",
        "target_cefr": estimated,
        "prompt": q["prompt"],
        "options": q["options"],
        "prev_feedback": prev_feedback,
        "state_token": next_state_token,
        "answer_key": next_answer_key
    }


@app.post("/assessment/ai/submit-writing")
def ai_assessment_submit_writing(payload: AiAssessmentWritingIn, db: Session = Depends(get_db)):
    state = verify_json(payload.state_token)

    if state.get("phase") != "writing":
        raise HTTPException(status_code=400, detail="Not in writing phase")

    user_id = int(state["user_id"])
    language_id = int(state["language_id"])
    estimated = str(state["estimated"])

    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.onboarding_status != "profile_completed":
        raise HTTPException(status_code=400, detail="User must complete profile first")

    lang = db.execute(select(Language).where(Language.id == language_id)).scalar_one_or_none()
    if not lang:
        raise HTTPException(status_code=400, detail="Invalid language_id")

    # regenerate prompt (stateless)
    wp = make_writing_prompt(lang.name, estimated)

    g = grade_writing(lang.name, estimated, wp["prompt"], payload.text)
    writing_score = int(g["score"])
    writing_level = writing_score_to_cefr(writing_score)

    cefr_order = ["A1", "A2", "B1", "B2", "C1", "C2"]
    final_cefr = estimated
    if cefr_order.index(writing_level) < cefr_order.index(final_cefr):
        final_cefr = writing_level

    # map CEFR to your enum
    saved_level = "beginner" if final_cefr in ("A1", "A2") else ("intermediate" if final_cefr in ("B1", "B2") else "advanced")

    # save final result in existing table
    db.add(LanguageAssessment(
        user_id=user_id,
        language_id=language_id,
        level=saved_level,
        score=writing_score
    ))

    user.onboarding_status = "assessed"
    db.commit()

    return {
        "message": "Assessment completed",
        "core_estimate": estimated,
        "writing_score": writing_score,
        "writing_level": writing_level,
        "final_cefr": final_cefr,
        "saved_level": saved_level,
        "user_status": user.onboarding_status,
        "feedback": g.get("feedback", "")
    }