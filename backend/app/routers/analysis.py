from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import DailyAnalysis, User
from app.routers.auth import get_current_user
from app.schemas.logs import AnalysisOut

router = APIRouter(prefix="/analysis", tags=["analysis"])


@router.get("")
async def get_analysis(
    date: date,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(DailyAnalysis)
        .where(DailyAnalysis.user_id == user.id)
        .where(DailyAnalysis.analysis_date == date)
    )
    row = result.scalar_one_or_none()
    if not row:
        return {"status": "not_generated"}
    return AnalysisOut.model_validate(row)


@router.get("/history", response_model=list[AnalysisOut])
async def history(
    days: int = Query(default=30, le=365),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cutoff = (datetime.utcnow().date() - timedelta(days=days))
    result = await db.execute(
        select(DailyAnalysis)
        .where(DailyAnalysis.user_id == user.id)
        .where(DailyAnalysis.analysis_date >= cutoff)
        .order_by(DailyAnalysis.analysis_date.desc())
    )
    return list(result.scalars().all())
