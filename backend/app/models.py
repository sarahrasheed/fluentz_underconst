from sqlalchemy import (
    Column, String, BigInteger, Boolean, Date, Enum, ForeignKey,
    SmallInteger, Integer, DateTime, TIMESTAMP, text
)
from sqlalchemy.orm import DeclarativeBase, relationship

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    full_name = Column(String(120), nullable=False)
    email = Column(String(190), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)

    role = Column(Enum("learner", "admin"), nullable=False, server_default="learner")
    is_email_verified = Column(Boolean, nullable=False, server_default=text("0"))
    onboarding_status = Column(
        Enum("registered", "verified", "assessed", "profile_completed"),
        nullable=False,
        server_default="registered"
    )

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"))

    otp_codes = relationship("EmailOtpCode", back_populates="user", cascade="all, delete")


class EmailOtpCode(Base):
    __tablename__ = "email_otp_codes"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    otp_hash = Column(String(64), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    attempts_left = Column(Integer, nullable=False, server_default=text("5"))

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))

    user = relationship("User", back_populates="otp_codes")

class Language(Base):
    __tablename__ = "languages"

    id = Column(SmallInteger, primary_key=True, autoincrement=True)
    code = Column(String(10), nullable=False, unique=True)
    name = Column(String(60), nullable=False)

class LanguageAssessment(Base):
    __tablename__ = "language_assessments"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    language_id = Column(SmallInteger, ForeignKey("languages.id", ondelete="RESTRICT"), nullable=False)

    score = Column(Integer, nullable=True)
    level = Column(Enum("beginner", "intermediate", "advanced"), nullable=False)

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))

class LearnerProfile(Base):
    __tablename__ = "learner_profile"

    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    date_of_birth = Column(Date, nullable=False)
    gender = Column(Enum("male", "female", "other"), nullable=False)
    short_description = Column(String(500), nullable=True)
    profile_photo_url = Column(String(500), nullable=True)

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"))


class UserLanguage(Base):
    __tablename__ = "user_languages"

    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    language_id = Column(SmallInteger, ForeignKey("languages.id", ondelete="RESTRICT"), primary_key=True)
    type = Column(Enum("native", "fluent", "target"), primary_key=True)
    proficiency_level = Column(Enum("beginner", "intermediate", "advanced"), nullable=True)

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))


class Interest(Base):
    __tablename__ = "interests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(80), nullable=False, unique=True)


class UserInterest(Base):
    __tablename__ = "user_interests"

    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    interest_id = Column(Integer, ForeignKey("interests.id", ondelete="RESTRICT"), primary_key=True)
