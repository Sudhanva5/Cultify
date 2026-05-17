from __future__ import annotations

import asyncio
import os
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    ExerciseLog,
    ExerciseReference,
    FoodLog,
    SleepLog,
    User,
    WeightLog,
)


def _client():
    import gspread
    from google.oauth2.service_account import Credentials

    if not settings.GOOGLE_SERVICE_ACCOUNT_JSON or not os.path.exists(settings.GOOGLE_SERVICE_ACCOUNT_JSON):
        raise RuntimeError("Google service account JSON not configured")
    scopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive",
    ]
    creds = Credentials.from_service_account_file(settings.GOOGLE_SERVICE_ACCOUNT_JSON, scopes=scopes)
    return gspread.authorize(creds)


async def _gather_user_data(db: AsyncSession, user_id: uuid.UUID) -> dict[str, list[list[Any]]]:
    weight_q = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.logged_at.asc())
    )
    weight_rows = [["logged_at", "weight_kg"]] + [
        [w.logged_at.isoformat(), w.weight_kg] for w in weight_q.scalars().all()
    ]

    sleep_q = await db.execute(
        select(SleepLog).where(SleepLog.user_id == user_id).order_by(SleepLog.date.asc())
    )
    sleep_rows = [["date", "slept_at", "woke_at", "duration_hours"]] + [
        [s.date.isoformat(), s.slept_at.isoformat(), s.woke_at.isoformat(), s.duration_hours]
        for s in sleep_q.scalars().all()
    ]

    food_q = await db.execute(
        select(FoodLog).where(FoodLog.user_id == user_id).order_by(FoodLog.logged_at.asc())
    )
    food_rows = [["logged_at", "meal_type", "description", "calories", "protein_g", "carbs_g", "fat_g", "claude_analysis"]] + [
        [
            f.logged_at.isoformat(),
            f.meal_type,
            f.description,
            f.estimated_calories,
            f.estimated_protein_g,
            f.estimated_carbs_g,
            f.estimated_fat_g,
            f.claude_food_analysis,
        ]
        for f in food_q.scalars().all()
    ]

    ex_q = await db.execute(
        select(ExerciseLog, ExerciseReference)
        .join(ExerciseReference, ExerciseLog.exercise_ref_id == ExerciseReference.id, isouter=True)
        .where(ExerciseLog.user_id == user_id)
        .order_by(ExerciseLog.logged_at.asc())
    )
    ex_rows = [["logged_at", "exercise", "body_part", "sets", "reps", "weight_kg", "duration_minutes", "notes"]] + [
        [
            log.logged_at.isoformat(),
            log.custom_name or (ref.name if ref else "Exercise"),
            ref.body_part if ref else None,
            log.sets,
            log.reps,
            log.weight_kg,
            log.duration_minutes,
            log.notes,
        ]
        for log, ref in ex_q.all()
    ]

    return {"Weight": weight_rows, "Sleep": sleep_rows, "Food": food_rows, "Exercises": ex_rows}


def _write_to_sheets(user_name: str, data: dict[str, list[list[Any]]]) -> str:
    gc = _client()
    title = f"CultifyMe — {user_name}"

    try:
        sh = gc.open(title)
    except Exception:
        sh = gc.create(title)
        if settings.GOOGLE_SHARE_EMAIL:
            try:
                sh.share(settings.GOOGLE_SHARE_EMAIL, perm_type="user", role="writer")
            except Exception:
                pass

    desired_titles = list(data.keys())
    existing = {ws.title: ws for ws in sh.worksheets()}

    for tab in desired_titles:
        rows = data[tab]
        cols = max((len(r) for r in rows), default=1)
        ws = existing.get(tab)
        if ws is None:
            ws = sh.add_worksheet(title=tab, rows=max(len(rows) + 5, 10), cols=cols)
        else:
            ws.clear()
        if rows:
            ws.update("A1", rows)

    # Remove the default "Sheet1" if present and unused
    if "Sheet1" in existing and "Sheet1" not in desired_titles and len(sh.worksheets()) > 1:
        try:
            sh.del_worksheet(existing["Sheet1"])
        except Exception:
            pass

    return sh.url


async def export_user_to_sheets(db: AsyncSession, user: User) -> str:
    data = await _gather_user_data(db, user.id)
    return await asyncio.to_thread(_write_to_sheets, user.name, data)
