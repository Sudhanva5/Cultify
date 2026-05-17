import os
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import aiofiles
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import (
    ExerciseLog,
    ExerciseReference,
    FoodLog,
    SleepLog,
    User,
    WeightLog,
)
from app.routers.auth import get_current_user
from app.schemas.logs import (
    ExerciseLogCreate,
    ExerciseLogOut,
    FoodLogOut,
    SleepLogCreate,
    SleepLogOut,
    WeightLogCreate,
    WeightLogOut,
)
from app.services import claude_service

router = APIRouter(prefix="/logs", tags=["logs"])


def _day_window(d: date) -> tuple[datetime, datetime]:
    start = datetime.combine(d, datetime.min.time(), tzinfo=timezone.utc)
    return start, start + timedelta(days=1)


# ============================================================
# EXERCISE
# ============================================================
@router.post("/exercise", response_model=ExerciseLogOut)
async def log_exercise(
    payload: ExerciseLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if not payload.exercise_ref_id and not payload.custom_name:
        raise HTTPException(status_code=400, detail="exercise_ref_id or custom_name is required")

    log = ExerciseLog(
        user_id=user.id,
        exercise_ref_id=payload.exercise_ref_id,
        custom_name=payload.custom_name,
        sets=payload.sets,
        reps=payload.reps,
        weight_kg=payload.weight_kg,
        duration_minutes=payload.duration_minutes,
        notes=payload.notes,
    )
    if payload.logged_at:
        log.logged_at = payload.logged_at

    db.add(log)
    await db.commit()
    await db.refresh(log)

    ref = None
    if log.exercise_ref_id:
        ref = await db.get(ExerciseReference, log.exercise_ref_id)

    return _exercise_out(log, ref)


@router.get("/exercise", response_model=list[ExerciseLogOut])
async def list_exercise(
    date: date,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    start, end = _day_window(date)
    stmt = (
        select(ExerciseLog, ExerciseReference)
        .join(ExerciseReference, ExerciseLog.exercise_ref_id == ExerciseReference.id, isouter=True)
        .where(ExerciseLog.user_id == user.id)
        .where(ExerciseLog.logged_at >= start)
        .where(ExerciseLog.logged_at < end)
        .order_by(ExerciseLog.logged_at.asc())
    )
    result = await db.execute(stmt)
    return [_exercise_out(log, ref) for log, ref in result.all()]


@router.delete("/exercise/{log_id}")
async def delete_exercise(
    log_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    log = await db.get(ExerciseLog, log_id)
    if not log or log.user_id != user.id:
        raise HTTPException(status_code=404, detail="Not found")
    await db.delete(log)
    await db.commit()
    return {"ok": True}


def _exercise_out(log: ExerciseLog, ref: ExerciseReference | None) -> ExerciseLogOut:
    return ExerciseLogOut(
        id=log.id,
        exercise_ref_id=log.exercise_ref_id,
        custom_name=log.custom_name,
        logged_at=log.logged_at,
        sets=log.sets,
        reps=log.reps,
        weight_kg=log.weight_kg,
        duration_minutes=log.duration_minutes,
        notes=log.notes,
        name=(ref.name if ref else log.custom_name),
        body_part=(ref.body_part if ref else None),
        gif_path=(ref.gif_path if ref else None),
    )


# ============================================================
# SLEEP
# ============================================================
@router.post("/sleep", response_model=SleepLogOut)
async def log_sleep(
    payload: SleepLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.woke_at <= payload.slept_at:
        raise HTTPException(status_code=400, detail="woke_at must be after slept_at")

    duration_hours = (payload.woke_at - payload.slept_at).total_seconds() / 3600.0

    # Replace existing sleep entry for that date
    existing = await db.execute(
        select(SleepLog).where(SleepLog.user_id == user.id).where(SleepLog.date == payload.date)
    )
    existing_row = existing.scalar_one_or_none()
    if existing_row:
        existing_row.slept_at = payload.slept_at
        existing_row.woke_at = payload.woke_at
        existing_row.duration_hours = duration_hours
        await db.commit()
        await db.refresh(existing_row)
        return existing_row

    log = SleepLog(
        user_id=user.id,
        date=payload.date,
        slept_at=payload.slept_at,
        woke_at=payload.woke_at,
        duration_hours=duration_hours,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


@router.get("/sleep", response_model=SleepLogOut | None)
async def get_sleep(
    date: date,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(SleepLog).where(SleepLog.user_id == user.id).where(SleepLog.date == date)
    )
    return result.scalar_one_or_none()


# ============================================================
# FOOD
# ============================================================
@router.post("/food", response_model=FoodLogOut)
async def log_food(
    photo: UploadFile = File(...),
    meal_type: str = Form(...),
    description: str = Form(""),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    user_dir = Path(settings.UPLOAD_DIR) / str(user.id)
    user_dir.mkdir(parents=True, exist_ok=True)

    suffix = Path(photo.filename or "").suffix.lower() or ".jpg"
    if suffix not in {".jpg", ".jpeg", ".png", ".webp", ".heic"}:
        suffix = ".jpg"
    file_id = uuid.uuid4().hex
    file_path = user_dir / f"{file_id}{suffix}"

    async with aiofiles.open(file_path, "wb") as f:
        while chunk := await photo.read(1024 * 1024):
            await f.write(chunk)

    # Save row up-front so a Claude failure still preserves the upload
    log = FoodLog(
        user_id=user.id,
        meal_type=meal_type,
        photo_path=f"{user.id}/{file_id}{suffix}",
        description=description or None,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)

    try:
        analysis = await claude_service.analyse_food_photo(str(file_path), description)
        log.estimated_calories = analysis.get("calories")
        log.estimated_protein_g = analysis.get("protein_g")
        log.estimated_carbs_g = analysis.get("carbs_g")
        log.estimated_fat_g = analysis.get("fat_g")
        log.claude_food_analysis = analysis.get("what_i_see")
        await db.commit()
        await db.refresh(log)
    except Exception as e:
        log.claude_food_analysis = f"Analysis failed: {e}"
        await db.commit()
        await db.refresh(log)

    return log


@router.get("/food", response_model=list[FoodLogOut])
async def list_food(
    date: date,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    start, end = _day_window(date)
    result = await db.execute(
        select(FoodLog)
        .where(FoodLog.user_id == user.id)
        .where(FoodLog.logged_at >= start)
        .where(FoodLog.logged_at < end)
        .order_by(FoodLog.logged_at.asc())
    )
    return list(result.scalars().all())


@router.delete("/food/{log_id}")
async def delete_food(
    log_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    log = await db.get(FoodLog, log_id)
    if not log or log.user_id != user.id:
        raise HTTPException(status_code=404, detail="Not found")
    # Best-effort photo cleanup
    if log.photo_path:
        try:
            os.remove(Path(settings.UPLOAD_DIR) / log.photo_path)
        except OSError:
            pass
    await db.delete(log)
    await db.commit()
    return {"ok": True}


# ============================================================
# WEIGHT
# ============================================================
@router.post("/weight", response_model=WeightLogOut)
async def log_weight(
    payload: WeightLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    log = WeightLog(user_id=user.id, weight_kg=payload.weight_kg)
    if payload.logged_at:
        log.logged_at = payload.logged_at
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


@router.get("/weight", response_model=list[WeightLogOut])
async def list_weight(
    days: int = 90,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    result = await db.execute(
        select(WeightLog)
        .where(WeightLog.user_id == user.id)
        .where(WeightLog.logged_at >= cutoff)
        .order_by(WeightLog.logged_at.asc())
    )
    return list(result.scalars().all())
