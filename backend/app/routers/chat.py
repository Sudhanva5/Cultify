from datetime import datetime

import pytz
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import ChatMessage, User
from app.routers.auth import get_current_user
from app.schemas.logs import (
    ChatMessageOut,
    ChatRequest,
    ChatResponse,
    ChatTodayResponse,
)
from app.services import claude_service

router = APIRouter(prefix="/chat", tags=["chat"])

IST = pytz.timezone("Asia/Kolkata")
DAILY_LIMIT = 5


def _today_ist():
    return datetime.now(IST).date()


@router.post("", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    today = _today_ist()

    count_q = await db.execute(
        select(func.count(ChatMessage.id))
        .where(ChatMessage.user_id == user.id)
        .where(ChatMessage.date == today)
        .where(ChatMessage.role == "user")
    )
    used = count_q.scalar() or 0
    if used >= DAILY_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"error": "Daily limit reached", "messages_used": DAILY_LIMIT, "limit": DAILY_LIMIT},
        )

    # Call Claude first (history in DB does NOT yet contain the new message;
    # claude_service appends it before sending).
    try:
        reply = await claude_service.chat_reply(db, user.id, user.name, today, payload.message)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Claude error: {e}")

    # Persist both turns after success
    db.add(ChatMessage(user_id=user.id, role="user", content=payload.message, date=today))
    db.add(ChatMessage(user_id=user.id, role="assistant", content=reply, date=today))
    await db.commit()

    return ChatResponse(response=reply, messages_used=used + 1, limit=DAILY_LIMIT)


@router.get("/today", response_model=ChatTodayResponse)
async def today(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    d = _today_ist()
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == user.id)
        .where(ChatMessage.date == d)
        .order_by(ChatMessage.created_at.asc())
    )
    msgs = list(result.scalars().all())
    used = sum(1 for m in msgs if m.role == "user")
    return ChatTodayResponse(
        messages=[ChatMessageOut.model_validate(m) for m in msgs],
        messages_used=used,
        limit=DAILY_LIMIT,
    )
