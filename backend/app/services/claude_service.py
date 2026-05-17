import asyncio
import base64
import json
import re
from datetime import date, timedelta
from typing import Any

import anthropic
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    ExerciseLog,
    ExerciseReference,
    FoodLog,
    SleepLog,
    WeightLog,
    DailyAnalysis,
    ChatMessage,
)

client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)


def _extract_json(text: str) -> dict | None:
    text = text.strip()
    # Strip markdown code fences if present
    fence = re.match(r"^```(?:json)?\s*(.*?)\s*```$", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Fall back: grab the first {...} block
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group(0))
            except json.JSONDecodeError:
                return None
        return None


# ============================================================
# 1. Food photo analysis
# ============================================================
def _analyse_food_photo_sync(image_path: str, description: str | None) -> dict:
    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")

    desc = description or "not provided"
    message = client.messages.create(
        model=settings.CLAUDE_MODEL,
        max_tokens=300,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": "image/jpeg", "data": image_data},
                    },
                    {
                        "type": "text",
                        "text": (
                            f'Analyse this meal photo. User description: "{desc}".\n\n'
                            "Estimate nutritional content based on what you see — "
                            "portion sizes, ingredients, cooking method visible.\n\n"
                            "Respond ONLY with valid JSON, nothing else:\n"
                            '{"calories": 450, "protein_g": 22, "carbs_g": 55, "fat_g": 12, '
                            '"what_i_see": "Brief description of plate contents and estimated portions"}'
                        ),
                    },
                ],
            }
        ],
    )

    raw = message.content[0].text
    parsed = _extract_json(raw) or {}
    return {
        "calories": float(parsed.get("calories") or 0) or None,
        "protein_g": float(parsed.get("protein_g") or 0) or None,
        "carbs_g": float(parsed.get("carbs_g") or 0) or None,
        "fat_g": float(parsed.get("fat_g") or 0) or None,
        "what_i_see": parsed.get("what_i_see") or raw.strip(),
    }


async def analyse_food_photo(image_path: str, description: str | None) -> dict:
    return await asyncio.to_thread(_analyse_food_photo_sync, image_path, description)


# ============================================================
# 2. Nightly analysis — context builder + Claude call
# ============================================================
async def _today_exercises(db: AsyncSession, user_id, day: date) -> list[str]:
    start = day
    end = day + timedelta(days=1)
    stmt = (
        select(ExerciseLog, ExerciseReference)
        .join(ExerciseReference, ExerciseLog.exercise_ref_id == ExerciseReference.id, isouter=True)
        .where(ExerciseLog.user_id == user_id)
        .where(ExerciseLog.logged_at >= start)
        .where(ExerciseLog.logged_at < end)
    )
    result = await db.execute(stmt)
    out: list[str] = []
    for log, ref in result.all():
        name = log.custom_name or (ref.name if ref else "Exercise")
        if log.sets and log.reps:
            weight = f" @ {log.weight_kg}kg" if log.weight_kg else ""
            out.append(f"{name}: {log.sets}×{log.reps}{weight}")
        elif log.duration_minutes:
            out.append(f"{name}: {log.duration_minutes} min")
        else:
            out.append(name)
    return out


async def _today_food(db: AsyncSession, user_id, day: date) -> tuple[list[str], float, float]:
    start = day
    end = day + timedelta(days=1)
    stmt = (
        select(FoodLog)
        .where(FoodLog.user_id == user_id)
        .where(FoodLog.logged_at >= start)
        .where(FoodLog.logged_at < end)
    )
    result = await db.execute(stmt)
    foods = result.scalars().all()
    items: list[str] = []
    total_cal, total_protein = 0.0, 0.0
    for f in foods:
        desc = f.description or f.claude_food_analysis or "meal"
        cal = f.estimated_calories or 0
        protein = f.estimated_protein_g or 0
        total_cal += cal
        total_protein += protein
        items.append(f"[{f.meal_type or 'meal'}] {desc[:80]} (~{int(cal)} kcal, {int(protein)}g protein)")
    return items, total_cal, total_protein


async def _today_sleep(db: AsyncSession, user_id, day: date) -> str:
    result = await db.execute(
        select(SleepLog).where(SleepLog.user_id == user_id).where(SleepLog.date == day)
    )
    sleep = result.scalar_one_or_none()
    if not sleep:
        return "not logged"
    return f"{sleep.duration_hours:.1f} hours ({sleep.slept_at.isoformat()} → {sleep.woke_at.isoformat()})"


async def _today_weight(db: AsyncSession, user_id, day: date) -> str:
    start = day
    end = day + timedelta(days=1)
    result = await db.execute(
        select(WeightLog)
        .where(WeightLog.user_id == user_id)
        .where(WeightLog.logged_at >= start)
        .where(WeightLog.logged_at < end)
        .order_by(WeightLog.logged_at.desc())
    )
    w = result.scalars().first()
    return f"{w.weight_kg} kg" if w else "not logged"


async def _week_summary(db: AsyncSession, user_id, day: date) -> dict:
    week_start = day - timedelta(days=6)

    # Sleep
    sleep_q = await db.execute(
        select(SleepLog.duration_hours)
        .where(SleepLog.user_id == user_id)
        .where(SleepLog.date >= week_start)
        .where(SleepLog.date <= day)
    )
    sleeps = [s for (s,) in sleep_q.all() if s]
    avg_sleep = round(sum(sleeps) / len(sleeps), 1) if sleeps else 0.0

    # Gym sessions = distinct days with at least one exercise log
    ex_q = await db.execute(
        select(ExerciseLog.logged_at)
        .where(ExerciseLog.user_id == user_id)
        .where(ExerciseLog.logged_at >= week_start)
        .where(ExerciseLog.logged_at < day + timedelta(days=1))
    )
    distinct_days = {d.date() for (d,) in ex_q.all()}
    gym_sessions = len(distinct_days)

    # Food
    food_q = await db.execute(
        select(FoodLog.estimated_calories, FoodLog.estimated_protein_g, FoodLog.logged_at)
        .where(FoodLog.user_id == user_id)
        .where(FoodLog.logged_at >= week_start)
        .where(FoodLog.logged_at < day + timedelta(days=1))
    )
    per_day_cal: dict[date, float] = {}
    per_day_prot: dict[date, float] = {}
    for cal, prot, ts in food_q.all():
        d = ts.date()
        per_day_cal[d] = per_day_cal.get(d, 0) + (cal or 0)
        per_day_prot[d] = per_day_prot.get(d, 0) + (prot or 0)
    avg_cal = round(sum(per_day_cal.values()) / len(per_day_cal)) if per_day_cal else 0
    avg_prot = round(sum(per_day_prot.values()) / len(per_day_prot)) if per_day_prot else 0

    return {
        "avg_sleep": avg_sleep,
        "gym_sessions": gym_sessions,
        "avg_calories": avg_cal,
        "avg_protein": avg_prot,
    }


async def _weight_history(db: AsyncSession, user_id) -> dict[str, float]:
    result = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.logged_at.asc())
    )
    out: dict[str, float] = {}
    for w in result.scalars().all():
        out[w.logged_at.date().isoformat()] = w.weight_kg
    return out


async def build_nightly_context(db: AsyncSession, user_id, user_name: str, day: date) -> str:
    exercises = await _today_exercises(db, user_id, day)
    food_items, total_cal, total_protein = await _today_food(db, user_id, day)
    sleep_str = await _today_sleep(db, user_id, day)
    weight_str = await _today_weight(db, user_id, day)
    week = await _week_summary(db, user_id, day)
    history = await _weight_history(db, user_id)

    food_block = (
        "\n".join(f"  - {i}" for i in food_items) + f"\n  TOTALS: ~{int(total_cal)} kcal, ~{int(total_protein)}g protein"
        if food_items else "none logged"
    )

    history_block = (
        "\n".join(f"  {d}: {kg} kg" for d, kg in history.items()) if history else "  no weight history yet"
    )

    return f"""You are analysing health data for {user_name}. Be direct and specific. No generic advice.

TODAY ({day.isoformat()}):
Exercises: {", ".join(exercises) if exercises else "none logged"}
Food:
{food_block}
Sleep: {sleep_str}
Weight: {weight_str}

LAST 7 DAYS:
- Avg sleep: {week['avg_sleep']} hrs
- Gym sessions: {week['gym_sessions']} of 7 days
- Avg calories: ~{week['avg_calories']} kcal/day
- Avg protein: ~{week['avg_protein']}g/day

WEIGHT HISTORY (for projection):
{history_block}

Respond with ONLY valid JSON in exactly this structure:
{{
  "day_remark": "2-3 sentences. Honest assessment of today specifically.",
  "nutrition": {{
    "calories_consumed": 1850,
    "protein_consumed": 98,
    "calories_target": 2200,
    "protein_target": 130,
    "efficiency_pct": 84,
    "suggestion": "One specific sentence about what to eat tomorrow based on today's gap."
  }},
  "weight_projection": "Based on X data points showing Y trend, projected weight in 4 weeks: Z kg, 8 weeks: Z kg. Brief reasoning.",
  "recommendations": [
    "Specific recommendation 1 based on actual data pattern",
    "Specific recommendation 2 based on actual data pattern",
    "Specific recommendation 3 based on actual data pattern"
  ]
}}

nutrition.calories_target and protein_target: use 2200 kcal and 130g protein as defaults unless there is enough data to infer differently.
efficiency_pct: (calories_consumed / calories_target * 0.5 + protein_consumed / protein_target * 0.5) * 100, capped at 100.
"""


async def run_nightly_for_user(db: AsyncSession, user_id, user_name: str, day: date) -> dict[str, Any]:
    prompt = await build_nightly_context(db, user_id, user_name, day)

    message = await asyncio.to_thread(
        client.messages.create,
        model=settings.CLAUDE_MODEL,
        max_tokens=2000,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text
    tokens = (message.usage.input_tokens + message.usage.output_tokens) if message.usage else 0

    parsed = _extract_json(raw) or {}
    return {
        "day_remark": parsed.get("day_remark"),
        "nutrition_json": parsed.get("nutrition"),
        "weight_projection": parsed.get("weight_projection"),
        "recommendations": parsed.get("recommendations"),
        "full_response": raw,
        "tokens_used": tokens,
    }


# ============================================================
# 3. Chat
# ============================================================
async def build_chat_context(db: AsyncSession, user_id, user_name: str, day: date) -> str:
    exercises = await _today_exercises(db, user_id, day)
    food_items, total_cal, total_protein = await _today_food(db, user_id, day)
    sleep_str = await _today_sleep(db, user_id, day)
    weight_str = await _today_weight(db, user_id, day)

    # Latest analysis (any date <= today, ordered desc)
    result = await db.execute(
        select(DailyAnalysis)
        .where(DailyAnalysis.user_id == user_id)
        .order_by(DailyAnalysis.analysis_date.desc())
        .limit(1)
    )
    latest = result.scalar_one_or_none()

    if latest:
        latest_block = (
            f"LATEST ANALYSIS ({latest.analysis_date.isoformat()}):\n"
            f"{latest.day_remark or 'No remark.'}\n"
            f"Recommendations: {latest.recommendations or 'N/A'}"
        )
    else:
        latest_block = "LATEST ANALYSIS (none yet):\nNo analysis generated yet."

    return (
        f"You are a health assistant for {user_name}. You have access to their logged health data.\n\n"
        f"TODAY'S DATA:\n"
        f"Exercises: {', '.join(exercises) if exercises else 'none logged'}\n"
        f"Food: {'; '.join(food_items) if food_items else 'none logged'} "
        f"(~{int(total_cal)} kcal, ~{int(total_protein)}g protein)\n"
        f"Sleep: {sleep_str}\n"
        f"Weight: {weight_str}\n\n"
        f"{latest_block}\n\n"
        f"Answer the user's question based only on this data. Be direct and specific. Max 150 words."
    )


async def chat_reply(
    db: AsyncSession,
    user_id,
    user_name: str,
    day: date,
    new_message: str,
) -> str:
    system_prompt = await build_chat_context(db, user_id, user_name, day)

    # Today's history in chronological order
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id)
        .where(ChatMessage.date == day)
        .order_by(ChatMessage.created_at.asc())
    )
    history = result.scalars().all()

    messages = [{"role": m.role, "content": m.content} for m in history]
    messages.append({"role": "user", "content": new_message})

    response = await asyncio.to_thread(
        client.messages.create,
        model=settings.CLAUDE_MODEL,
        max_tokens=500,
        system=system_prompt,
        messages=messages,
    )
    return response.content[0].text.strip()
