import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import analysis, auth, chat, exercises, export, logs
from app.services.cron_service import start_scheduler, stop_scheduler

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s — %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    Path(settings.STATIC_DIR, "exercises").mkdir(parents=True, exist_ok=True)
    start_scheduler()
    try:
        yield
    finally:
        stop_scheduler()


app = FastAPI(title="CultifyMe", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

app.include_router(auth.router)
app.include_router(logs.router)
app.include_router(exercises.router)
app.include_router(analysis.router)
app.include_router(chat.router)
app.include_router(export.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
