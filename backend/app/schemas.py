from pydantic import BaseModel, EmailStr, Field
from typing import Literal, Optional
from datetime import date
from typing import List
from typing import Literal

class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)

class RegisterOut(BaseModel):
    user_id: int
    message: str

class VerifyOtpIn(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")

class ResendOtpIn(BaseModel):
    email: EmailStr

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    onboarding_status: Literal["registered","verified","assessed","profile_completed"]
    role: Literal["learner","admin"]

class SubmitAssessmentIn(BaseModel):
    language_id: int
    level: Literal["beginner", "intermediate", "advanced"]
    score: Optional[int] = None

class CompleteProfileIn(BaseModel):
    user_id: int
    date_of_birth: date
    gender: Literal["male", "female", "other"]
    short_description: Optional[str] = Field(default=None, max_length=500)
    profile_photo_url: Optional[str] = Field(default=None, max_length=500)

    native_language_id: int
    fluent_language_ids: List[int] = []
    target_language_ids: List[int]

    interest_ids: List[int] = []

class AiAssessmentStartIn(BaseModel):
    user_id: int
    language_id: int

class AiAssessmentAnswerIn(BaseModel):
    session_id: int
    choice: Literal["A","B","C","D"]

class AiAssessmentWritingIn(BaseModel):
    session_id: int
    text: str