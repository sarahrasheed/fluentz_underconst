from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, desc
from datetime import datetime, timedelta
from .models import LearnerProfile, UserLanguage, UserInterest, Language, Interest
from .schemas import CompleteProfileIn

from .db import get_db
from .models import User, EmailOtpCode, LanguageAssessment
from .schemas import (
    RegisterIn, RegisterOut,
    VerifyOtpIn, ResendOtpIn,
    LoginIn, LoginOut,
    SubmitAssessmentIn
)
from .security import hash_password, verify_password, create_access_token, generate_otp, otp_hash
from .emailer import send_otp_email

import json
from .models_assessment import AssessmentSession, AssessmentItem
from .cefr import harder, easier, writing_score_to_cefr
from .ai_test import make_mcq, grade_mcq, make_writing_prompt, grade_writing
from .schemas import AiAssessmentStartIn, AiAssessmentAnswerIn, AiAssessmentWritingIn
from .models import Language


app = FastAPI(title="Fluentz API")

OTP_EXPIRE_MINUTES = 10
OTP_ATTEMPTS = 5

@app.get("/health")
def health():
    return {"status": "ok"}

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

@app.post("/auth/verify-otp")
def verify_otp(payload: VerifyOtpIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.is_email_verified:
        return {"message": "Already verified"}

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

    return {"message": "Email verified"}

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
        "onboarding_status": user.onboarding_status
    }

# --- Assessment submit (simple MVP: backend trusts the frontend test result) ---
@app.post("/assessment/submit")
def submit_assessment(user_id: int, payload: SubmitAssessmentIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.onboarding_status not in ("verified", "assessed"):
        raise HTTPException(status_code=400, detail="User must verify email first")

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

@app.post("/profile/complete")
def complete_profile(payload: CompleteProfileIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == payload.user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.onboarding_status != "assessed":
        raise HTTPException(status_code=400, detail="User must finish assessment first")

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

    # For target languages: use latest assessment level for each target language (if exists)
    for lid in payload.target_language_ids:
        if lid == payload.native_language_id:
            continue

        assessment = db.execute(
            select(LanguageAssessment)
            .where(LanguageAssessment.user_id == user.id, LanguageAssessment.language_id == lid)
            .order_by(desc(LanguageAssessment.created_at))
            .limit(1)
        ).scalar_one_or_none()

        level = assessment.level if assessment else None

        db.add(UserLanguage(
            user_id=user.id,
            language_id=lid,
            type="target",
            proficiency_level=level
        ))

    # Interests
    for iid in sorted(set(payload.interest_ids)):
        db.add(UserInterest(user_id=user.id, interest_id=iid))

    user.onboarding_status = "profile_completed"
    db.commit()

    return {"message": "Profile completed", "status": user.onboarding_status}

@app.get("/meta/languages")
def list_languages(db: Session = Depends(get_db)):
    rows = db.execute(select(Language).order_by(Language.name)).scalars().all()
    return [{"id": int(r.id), "code": r.code, "name": r.name} for r in rows]

@app.get("/meta/interests")
def list_interests(db: Session = Depends(get_db)):
    rows = db.execute(select(Interest).order_by(Interest.name)).scalars().all()
    return [{"id": int(r.id), "name": r.name} for r in rows]

MAX_CORE_QUESTIONS = 8

@app.post("/assessment/ai/start")
def ai_assessment_start(payload: AiAssessmentStartIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.id == payload.user_id)).scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")
    if user.onboarding_status != "verified":
        raise HTTPException(400, "User must be verified first")

    lang = db.execute(select(Language).where(Language.id == payload.language_id)).scalar_one_or_none()
    if not lang:
        raise HTTPException(400, "Invalid language_id")

    s = AssessmentSession(user_id=user.id, language_id=lang.id, status="in_progress", estimated_level="B1", step=0)
    db.add(s)
    db.commit()
    db.refresh(s)

    # create step 1 MCQ at estimated_level
    q = make_mcq(lang.name, s.estimated_level)
    item = AssessmentItem(
        session_id=s.id,
        step=1,
        item_type="mcq",
        target_cefr=s.estimated_level,
        prompt_text=q["prompt"],
        options_json=json.dumps(q["options"]),
        correct_option=q["correct"]
    )
    db.add(item)
    s.step = 1
    db.commit()

    return {
        "session_id": int(s.id),
        "step": 1,
        "target_cefr": s.estimated_level,
        "type": "mcq",
        "prompt": item.prompt_text,
        "options": json.loads(item.options_json),
    }


@app.post("/assessment/ai/answer-mcq")
def ai_assessment_answer(payload: AiAssessmentAnswerIn, db: Session = Depends(get_db)):
    s = db.execute(select(AssessmentSession).where(AssessmentSession.id == payload.session_id)).scalar_one_or_none()
    if not s or s.status != "in_progress":
        raise HTTPException(400, "Invalid session")

    lang = db.execute(select(Language).where(Language.id == s.language_id)).scalar_one()

    item = db.execute(
        select(AssessmentItem).where(
            AssessmentItem.session_id == s.id,
            AssessmentItem.step == s.step
        )
    ).scalar_one_or_none()

    if not item or item.item_type != "mcq":
        raise HTTPException(400, "No current MCQ item")

    # Grade MCQ
    q_options = json.loads(item.options_json or "{}")
    # explanation comes from the generator; we stored none, so we’ll keep short feedback
    correct = (item.correct_option or "").strip()

    # quick AI-free feedback for MVP (you can improve later)
    is_correct = payload.choice == correct
    score = 10 if is_correct else 0
    feedback = "Correct." if is_correct else f"Incorrect. Correct answer is {correct}."

    item.user_answer = payload.choice
    item.score = score
    item.feedback = feedback
    item.answered_at = datetime.utcnow()

    # Update estimated level based on performance
    if score == 10:
        s.estimated_level = harder(s.estimated_level)
    else:
        s.estimated_level = easier(s.estimated_level)

    next_step = s.step + 1

    # If finished core, move to writing
    if next_step > MAX_CORE_QUESTIONS:
        s.status = "awaiting_writing"
        db.commit()

        wp = make_writing_prompt(lang.name, s.estimated_level)
        writing_item = AssessmentItem(
            session_id=s.id,
            step=9,
            item_type="writing",
            target_cefr=s.estimated_level,
            prompt_text=wp["prompt"],
            options_json=json.dumps({"min_words": wp["min_words"], "max_words": wp["max_words"]})
        )
        db.add(writing_item)
        db.commit()

        return {
            "done_core": True,
            "status": s.status,
            "estimated_level": s.estimated_level,
            "type": "writing",
            "prompt": writing_item.prompt_text,
            "limits": json.loads(writing_item.options_json),
            "prev_feedback": item.feedback
        }

    # Otherwise generate next MCQ
    q = make_mcq(lang.name, s.estimated_level)
    next_item = AssessmentItem(
        session_id=s.id,
        step=next_step,
        item_type="mcq",
        target_cefr=s.estimated_level,
        prompt_text=q["prompt"],
        options_json=json.dumps(q["options"]),
        correct_option=q["correct"]
    )
    db.add(next_item)
    s.step = next_step
    db.commit()

    return {
        "done_core": False,
        "step": next_step,
        "target_cefr": s.estimated_level,
        "type": "mcq",
        "prompt": next_item.prompt_text,
        "options": json.loads(next_item.options_json),
        "prev_feedback": item.feedback
    }


@app.post("/assessment/ai/submit-writing")
def ai_assessment_submit_writing(payload: AiAssessmentWritingIn, db: Session = Depends(get_db)):
    s = db.execute(select(AssessmentSession).where(AssessmentSession.id == payload.session_id)).scalar_one_or_none()
    if not s or s.status != "awaiting_writing":
        raise HTTPException(400, "Session not awaiting writing")

    lang = db.execute(select(Language).where(Language.id == s.language_id)).scalar_one()

    writing_item = db.execute(
        select(AssessmentItem).where(
            AssessmentItem.session_id == s.id,
            AssessmentItem.step == 9,
            AssessmentItem.item_type == "writing"
        )
    ).scalar_one_or_none()

    if not writing_item:
        raise HTTPException(400, "Writing task not found")

    g = grade_writing(lang.name, s.estimated_level, writing_item.prompt_text, payload.text)

    writing_item.user_answer = payload.text
    writing_item.score = int(g["score"])
    writing_item.feedback = g.get("feedback", "")
    writing_item.answered_at = datetime.utcnow()

    writing_level = writing_score_to_cefr(int(g["score"]))

    # Final CEFR = MIN(core estimate, writing)
    cefr_order = ["A1","A2","B1","B2","C1","C2"]
    final_level = s.estimated_level
    if cefr_order.index(writing_level) < cefr_order.index(final_level):
        final_level = writing_level

    # Save final result into your existing language_assessments table
    db.add(LanguageAssessment(
        user_id=s.user_id,
        language_id=s.language_id,
        level="beginner" if final_level in ("A1","A2") else ("intermediate" if final_level in ("B1","B2") else "advanced"),
        score=int(g["score"])  # keep for now (0..15); we can normalize later
    ))

    user = db.execute(select(User).where(User.id == s.user_id)).scalar_one()
    user.onboarding_status = "assessed"

    s.status = "completed"
    s.completed_at = datetime.utcnow()

    db.commit()

    return {
        "message": "Assessment completed",
        "core_estimate": s.estimated_level,
        "writing_score": int(g["score"]),
        "writing_level": writing_level,
        "final_cefr": final_level,
        "user_status": user.onboarding_status
    }
