from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import (
    ChatMessage,
    DailyAnalysis,
    ExerciseLog,
    FoodLog,
    SleepLog,
    User,
    WeightLog,
)
from app.routers.auth import get_current_user
from app.services.sheets_service import export_user_to_sheets

router = APIRouter(prefix="/export", tags=["export"])


@router.get("/sheets")
async def export_sheets(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    try:
        url = await export_user_to_sheets(db, user)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sheets export failed: {e}")
    return {"sheet_url": url}


def _serialize(row):
    d = {c.name: getattr(row, c.name) for c in row.__table__.columns}
    for k, v in d.items():
        if hasattr(v, "isoformat"):
            d[k] = v.isoformat()
        elif isinstance(v, (bytes, bytearray)):
            d[k] = None
    return d


@router.get("/json")
async def export_json(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    async def fetch(model, order_col):
        result = await db.execute(select(model).where(model.user_id == user.id).order_by(order_col))
        return [_serialize(r) for r in result.scalars().all()]

    return {
        "user": {"id": str(user.id), "email": user.email, "name": user.name},
        "exercise_logs": await fetch(ExerciseLog, ExerciseLog.logged_at.asc()),
        "sleep_logs": await fetch(SleepLog, SleepLog.date.asc()),
        "food_logs": await fetch(FoodLog, FoodLog.logged_at.asc()),
        "weight_logs": await fetch(WeightLog, WeightLog.logged_at.asc()),
        "daily_analyses": await fetch(DailyAnalysis, DailyAnalysis.analysis_date.asc()),
        "chat_messages": await fetch(ChatMessage, ChatMessage.created_at.asc()),
    }
