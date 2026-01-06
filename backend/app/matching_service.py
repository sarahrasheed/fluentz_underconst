from __future__ import annotations
from typing import Dict, List, Optional, Tuple
from datetime import date

from sqlalchemy.orm import Session
from sqlalchemy import select, and_

from .models import User, LearnerProfile, UserLanguage, UserInterest, Interest

WEIGHT_INTERESTS = 0.60
WEIGHT_AGE = 0.40


def _calculate_age(dob: date) -> Optional[int]:
    try:
        today = date.today()
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    except Exception:
        return None


def _age_score(age1: Optional[int], age2: Optional[int]) -> Optional[float]:
    if age1 is None or age2 is None:
        return None
    diff = abs(age1 - age2)
    return 1.0 / (1.0 + diff)  # 0..1


def _interest_score(a: set[int], b: set[int]) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0  # 0..1


def _get_single_language(db: Session, user_id: int, lang_type: str) -> Optional[int]:
    row = db.execute(
        select(UserLanguage.language_id)
        .where(
            and_(
                UserLanguage.user_id == user_id,
                UserLanguage.type == lang_type
            )
        )
        .limit(1)
    ).scalar_one_or_none()
    return int(row) if row is not None else None


def _get_user_interest_ids(db: Session, user_id: int) -> set[int]:
    rows = db.execute(
        select(UserInterest.interest_id).where(UserInterest.user_id == user_id)
    ).scalars().all()
    return set(int(x) for x in rows)


def _get_interest_names(db: Session, interest_ids: set[int]) -> List[str]:
    if not interest_ids:
        return []
    rows = db.execute(
        select(Interest.id, Interest.name).where(Interest.id.in_(list(interest_ids)))
    ).all()
    mp = {int(i): n for i, n in rows}
    return [mp[i] for i in interest_ids if i in mp]


def get_recommendations(db: Session, user_id: int, limit: int = 20) -> List[Dict]:
    """
    Returns a list of recommended matches for user_id.
    Language is a CONDITION:
      user.native == other.target AND user.target == other.native
    Score:
      interests: 0.60 (Jaccard)
      age:       0.40 (1/(1+diff))
      if age missing => only interests
    """

    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if not user:
        return []

    # require profile row
    me_profile = db.execute(select(LearnerProfile).where(LearnerProfile.user_id == user_id)).scalar_one_or_none()
    if not me_profile:
        return []

    my_native = _get_single_language(db, user_id, "native")
    my_target = _get_single_language(db, user_id, "target")
    if my_native is None or my_target is None:
        return []

    my_interests = _get_user_interest_ids(db, user_id)
    my_age = _calculate_age(me_profile.date_of_birth) if me_profile.date_of_birth else None

    # candidates: opposite language condition
    candidate_ids = db.execute(
        select(UserLanguage.user_id)
        .where(UserLanguage.type == "native", UserLanguage.language_id == my_target)
    ).scalars().all()

    candidate_ids = set(int(x) for x in candidate_ids if int(x) != user_id)

    # must also have target == my_native
    target_match_ids = db.execute(
        select(UserLanguage.user_id)
        .where(UserLanguage.type == "target", UserLanguage.language_id == my_native)
    ).scalars().all()

    target_match_ids = set(int(x) for x in target_match_ids)
    candidate_ids = candidate_ids & target_match_ids

    if not candidate_ids:
        return []

    # fetch candidate profiles/users
    candidates = db.execute(
        select(User, LearnerProfile)
        .join(LearnerProfile, LearnerProfile.user_id == User.id)
        .where(User.id.in_(list(candidate_ids)))
    ).all()

    results: List[Tuple[Dict, float]] = []

    for u, prof in candidates:
        other_id = int(u.id)

        other_interests = _get_user_interest_ids(db, other_id)
        other_age = _calculate_age(prof.date_of_birth) if prof.date_of_birth else None

        i_score = _interest_score(my_interests, other_interests)
        a_score = _age_score(my_age, other_age)

        if a_score is None:
            final = i_score
        else:
            final = (WEIGHT_INTERESTS * i_score) + (WEIGHT_AGE * a_score)

        shared_ids = my_interests & other_interests
        shared_names = _get_interest_names(db, shared_ids)

        results.append((
            {
                "user_id": other_id,
                "full_name": u.full_name,
                "email": u.email,
                "age": other_age,
                "profile_photo_url": prof.profile_photo_url,
                "shared_interests": shared_names,
            },
            float(final)
        ))

    results.sort(key=lambda x: x[1], reverse=True)
    out = []
    for item, score in results[:limit]:
        item["score"] = score
        out.append(item)
    return out