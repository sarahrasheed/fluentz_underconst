from sqlalchemy import select
from app.db import SessionLocal
from app import models

LANGUAGES = [
    # code, name
    ("en", "English"),
    ("ar", "Arabic"),
    ("fr", "French"),
    ("es", "Spanish"),
    ("de", "German"),
    ("tr", "Turkish"),
]

INTERESTS = [
    "Travel",
    "Business",
    "Technology",
    "Movies & TV",
    "Music",
    "Food",
    "Sports",
    "Gaming",
    "Education",
]

def main():
    db = SessionLocal()
    try:
        # --- Languages ---
        existing_lang_codes = set(
            db.execute(select(models.Language.code)).scalars().all()
        )
        added_lang = 0
        for code, name in LANGUAGES:
            if code not in existing_lang_codes:
                db.add(models.Language(code=code, name=name))
                added_lang += 1

        # --- Interests ---
        existing_interests = set(
            db.execute(select(models.Interest.name)).scalars().all()
        )
        added_int = 0
        for name in INTERESTS:
            if name not in existing_interests:
                db.add(models.Interest(name=name))
                added_int += 1

        db.commit()
        print(f"✅ Seed done. Languages added: {added_lang}, Interests added: {added_int}")

    finally:
        db.close()

if __name__ == "__main__":
    main()