import sys

print(">>> Cultify boot: starting imports", file=sys.stderr, flush=True)

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

print(">>> Cultify boot: importing config", file=sys.stderr, flush=True)
from app.config import settings
print(f">>> Cultify boot: config ok. UPLOAD_DIR={settings.UPLOAD_DIR} STATIC_DIR={settings.STATIC_DIR}", file=sys.stderr, flush=True)

print(">>> Cultify boot: importing routers", file=sys.stderr, flush=True)
from app.routers import analysis, auth, chat, exercises, export, logs
print(">>> Cultify boot: routers ok", file=sys.stderr, flush=True)

print(">>> Cultify boot: importing cron service", file=sys.stderr, flush=True)
from app.services.cron_service import start_scheduler, stop_scheduler
print(">>> Cultify boot: cron service ok", file=sys.stderr, flush=True)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s — %(message)s")

# Ensure upload + static directories exist before StaticFiles mounts them.
print(">>> Cultify boot: creating dirs", file=sys.stderr, flush=True)
Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
Path(settings.STATIC_DIR, "exercises").mkdir(parents=True, exist_ok=True)
print(">>> Cultify boot: dirs ok", file=sys.stderr, flush=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(">>> Cultify boot: lifespan start", file=sys.stderr, flush=True)
    start_scheduler()
    print(">>> Cultify boot: scheduler started", file=sys.stderr, flush=True)
    try:
        yield
    finally:
        stop_scheduler()


print(">>> Cultify boot: building FastAPI app", file=sys.stderr, flush=True)
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

print(">>> Cultify boot: app fully constructed, uvicorn handing over", file=sys.stderr, flush=True)


@app.get("/health")
async def health():
    return {"status": "ok"}
