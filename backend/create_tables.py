from app.db import engine
from app.models import Base  # wherever your SQLAlchemy Base is defined

def main():
    Base.metadata.create_all(bind=engine)
    print("✅ Tables created successfully.")

if __name__ == "__main__":
    main()