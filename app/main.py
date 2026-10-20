"""Notes API: простий REST API на FastAPI + PostgreSQL (SQLAlchemy)."""
import os
import socket
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import DateTime, String, Text, create_engine, select, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

# Рядок підключення приходить ТІЛЬКИ зі змінної середовища (у хмарі - з Secrets Manager).
DATABASE_URL = os.environ["DATABASE_URL"]
APP_VERSION = os.getenv("APP_VERSION", "dev")

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class NoteIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: str = ""


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    content: str
    created_at: datetime


@asynccontextmanager
async def lifespan(_: FastAPI):
    # База може стартувати повільніше за застосунок - пробуємо кілька разів.
    for attempt in range(30):
        try:
            Base.metadata.create_all(engine)
            break
        except Exception as exc:  # noqa: BLE001
            print(f"DB not ready ({attempt + 1}/30): {exc}", flush=True)
            time.sleep(2)
    else:
        raise RuntimeError("Database is unavailable")
    yield


app = FastAPI(title="Notes API", version=APP_VERSION, lifespan=lifespan)


def get_db():
    with SessionLocal() as db:
        yield db


@app.get("/")
def root():
    # hostname = ID контейнера: при оновленні сторінки видно, що відповідають різні екземпляри за ALB
    return {"service": "notes-api-v2", "version": APP_VERSION, "hostname": socket.gethostname()}


@app.get("/health")
def health():
    """Для health check балансувальника: лише 'процес живий', без звернення до БД."""
    return {"status": "ok"}


@app.get("/health/db")
def health_db(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok", "db": "up"}


@app.get("/api/notes", response_model=list[NoteOut])
def list_notes(db: Session = Depends(get_db)):
    return db.scalars(select(Note).order_by(Note.id)).all()


@app.post("/api/notes", response_model=NoteOut, status_code=201)
def create_note(payload: NoteIn, db: Session = Depends(get_db)):
    note = Note(**payload.model_dump())
    db.add(note)
    db.commit()
    return note


@app.get("/api/notes/{note_id}", response_model=NoteOut)
def get_note(note_id: int, db: Session = Depends(get_db)):
    note = db.get(Note, note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@app.put("/api/notes/{note_id}", response_model=NoteOut)
def update_note(note_id: int, payload: NoteIn, db: Session = Depends(get_db)):
    note = db.get(Note, note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    note.title, note.content = payload.title, payload.content
    db.commit()
    return note


@app.delete("/api/notes/{note_id}", status_code=204)
def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.get(Note, note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    db.delete(note)
    db.commit()
    return Response(status_code=204)
