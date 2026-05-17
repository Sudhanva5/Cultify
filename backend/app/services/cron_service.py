import logging
from datetime import datetime

import pytz
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.database import SessionLocal
from app.models import DailyAnalysis, User
from app.services import claude_service

logger = logging.getLogger("cultify.cron")

IST = pytz.timezone("Asia/Kolkata")
scheduler = AsyncIOScheduler(timezone=IST)


async def run_nightly_analysis() -> None:
    today_ist = datetime.now(IST).date()
    logger.info("nightly analysis kicking off for %s", today_ist)

    async with SessionLocal() as db:
        users = (await db.execute(select(User))).scalars().all()

    for user in users:
        try:
            async with SessionLocal() as db:
                result = await claude_service.run_nightly_for_user(db, user.id, user.name, today_ist)

                stmt = pg_insert(DailyAnalysis).values(
                    user_id=user.id,
                    analysis_date=today_ist,
                    day_remark=result["day_remark"],
                    nutrition_json=result["nutrition_json"],
                    weight_projection=result["weight_projection"],
                    recommendations=result["recommendations"],
                    full_response=result["full_response"],
                    tokens_used=result["tokens_used"],
                )
                stmt = stmt.on_conflict_do_update(
                    constraint="uq_daily_analysis_user_date",
                    set_={
                        "day_remark": stmt.excluded.day_remark,
                        "nutrition_json": stmt.excluded.nutrition_json,
                        "weight_projection": stmt.excluded.weight_projection,
                        "recommendations": stmt.excluded.recommendations,
                        "full_response": stmt.excluded.full_response,
                        "tokens_used": stmt.excluded.tokens_used,
                    },
                )
                await db.execute(stmt)
                await db.commit()
                logger.info("nightly analysis ok for user=%s", user.email)
        except Exception:
            logger.exception("nightly analysis FAILED for user=%s — continuing", user.email)


def start_scheduler() -> None:
    if scheduler.running:
        return
    scheduler.add_job(
        run_nightly_analysis,
        CronTrigger(hour=22, minute=0),
        id="nightly_analysis",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("scheduler started — nightly analysis at 22:00 IST")


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
