import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import ExerciseReference, User
from app.routers.auth import get_current_user
from app.schemas.logs import ExerciseReferenceOut

router = APIRouter(prefix="/exercises", tags=["exercises"])


@router.get("", response_model=list[ExerciseReferenceOut])
async def list_exercises(
    body_part: str | None = None,
    search: str | None = None,
    cult_only: bool = True,
    limit: int = Query(default=100, le=500),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    stmt = select(ExerciseReference)
    if cult_only:
        stmt = stmt.where(ExerciseReference.is_cult_relevant.is_(True))
    if body_part and body_part.lower() != "all":
        stmt = stmt.where(func.lower(ExerciseReference.body_part) == body_part.lower())
    if search:
        like = f"%{search.lower()}%"
        stmt = stmt.where(func.lower(ExerciseReference.name).like(like))

    stmt = stmt.order_by(ExerciseReference.name.asc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return list(result.scalars().all())


@router.get("/{ex_id}", response_model=ExerciseReferenceOut)
async def get_exercise(
    ex_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    ex = await db.get(ExerciseReference, ex_id)
    if not ex:
        raise HTTPException(status_code=404, detail="Not found")
    return ex
