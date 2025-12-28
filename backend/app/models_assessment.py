from sqlalchemy import Column, BigInteger, SmallInteger, Integer, Enum, Text, DateTime, TIMESTAMP, ForeignKey, text
from .models import Base  # uses your existing Base

class AssessmentSession(Base):
    __tablename__ = "assessment_sessions"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    language_id = Column(SmallInteger, ForeignKey("languages.id", ondelete="RESTRICT"), nullable=False)

    status = Column(Enum("in_progress","awaiting_writing","completed","cancelled"), nullable=False, server_default="in_progress")
    estimated_level = Column(Enum("A1","A2","B1","B2","C1","C2"), nullable=False, server_default="B1")
    step = Column(Integer, nullable=False, server_default=text("0"))

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    completed_at = Column(DateTime, nullable=True)


class AssessmentItem(Base):
    __tablename__ = "assessment_items"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    session_id = Column(BigInteger, ForeignKey("assessment_sessions.id", ondelete="CASCADE"), nullable=False)
    step = Column(Integer, nullable=False)

    item_type = Column(Enum("mcq","writing"), nullable=False, server_default="mcq")
    target_cefr = Column(Enum("A1","A2","B1","B2","C1","C2"), nullable=False)

    prompt_text = Column(Text, nullable=False)
    options_json = Column(Text, nullable=True)
    correct_option = Column(Text, nullable=True)

    user_answer = Column(Text, nullable=True)
    score = Column(Integer, nullable=True)
    feedback = Column(Text, nullable=True)

    created_at = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    answered_at = Column(DateTime, nullable=True)
