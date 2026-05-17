"""Seed the exercise_reference table from free-exercise-db.

Idempotent — re-running skips already-seeded rows (matched by external_id /
name for custom rows). Image download failures are logged and skipped.
"""
import asyncio
import json
import os
import sys
from pathlib import Path

import requests

# Make `app.*` importable when invoked from anywhere
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select
from app.database import SessionLocal
from app.models import ExerciseReference

JSON_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
IMAGE_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"

NON_CULT_EQUIPMENT = {
    "assisted",
    "sled machine",
    "bosu ball",
    "leverage machine",
    "skierg machine",
    "rope",
    "roller",
    "wheel roller",
}

STATIC_DIR = Path(os.environ.get("STATIC_DIR", "static"))
EXERCISE_IMG_DIR = STATIC_DIR / "exercises"

CUSTOM_EXERCISES = [
    {"name": "Cult Live Class", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "HRX Workout", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Badminton", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Swimming", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Dance Practice", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Walk / Run (Outdoor)", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
]


def download_image(ext_id: str) -> str | None:
    target = EXERCISE_IMG_DIR / f"{ext_id}.jpg"
    if target.exists():
        return f"exercises/{ext_id}.jpg"
    url = f"{IMAGE_BASE}/{ext_id}/0.jpg"
    try:
        r = requests.get(url, timeout=15)
        if r.status_code != 200:
            return None
        target.write_bytes(r.content)
        return f"exercises/{ext_id}.jpg"
    except Exception as e:
        print(f"  image download failed for {ext_id}: {e}", flush=True)
        return None


def map_body_part(primary_muscles: list[str], category: str) -> str:
    if not primary_muscles:
        return category or "other"
    m = primary_muscles[0].lower()
    mapping = {
        "chest": "chest",
        "lats": "back", "middle back": "back", "lower back": "back", "neck": "back", "traps": "back",
        "shoulders": "shoulders",
        "biceps": "arms", "triceps": "arms", "forearms": "arms",
        "quadriceps": "legs", "hamstrings": "legs", "glutes": "legs", "calves": "legs", "adductors": "legs", "abductors": "legs",
        "abdominals": "core",
    }
    if m in mapping:
        return mapping[m]
    if category and category.lower() in {"cardio"}:
        return "cardio"
    return "other"


async def seed():
    EXERCISE_IMG_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Downloading exercise catalogue from {JSON_URL}", flush=True)
    try:
        resp = requests.get(JSON_URL, timeout=60)
        resp.raise_for_status()
        exercises = resp.json()
    except Exception as e:
        print(f"FATAL: could not fetch exercise catalogue: {e}", flush=True)
        return

    print(f"Catalogue has {len(exercises)} exercises", flush=True)

    async with SessionLocal() as db:
        # Build set of existing external_ids and names in one shot
        existing = await db.execute(select(ExerciseReference.external_id, ExerciseReference.name))
        existing_ids: set[str] = set()
        existing_names: set[str] = set()
        for ext_id, name in existing.all():
            if ext_id:
                existing_ids.add(ext_id)
            if name:
                existing_names.add(name)

        inserted = 0
        skipped = 0
        for idx, ex in enumerate(exercises):
            ext_id = ex.get("id")
            if not ext_id:
                continue
            if ext_id in existing_ids:
                skipped += 1
                continue

            equipment = (ex.get("equipment") or "").lower() or None
            is_cult_relevant = equipment not in NON_CULT_EQUIPMENT if equipment else True

            primary_muscles = ex.get("primaryMuscles") or []
            secondary_muscles = ex.get("secondaryMuscles") or []
            category = ex.get("category") or ""
            body_part = map_body_part(primary_muscles, category)
            target_muscle = primary_muscles[0] if primary_muscles else None

            gif_path = download_image(ext_id)

            row = ExerciseReference(
                external_id=ext_id,
                name=ex.get("name") or ext_id,
                body_part=body_part,
                equipment=equipment,
                target_muscle=target_muscle,
                secondary_muscles=secondary_muscles,
                instructions=ex.get("instructions") or [],
                gif_path=gif_path,
                is_cult_relevant=is_cult_relevant,
            )
            db.add(row)
            inserted += 1
            if inserted % 50 == 0:
                await db.commit()
                print(f"  inserted {inserted}/{len(exercises)}…", flush=True)

        await db.commit()
        print(f"Catalogue done — inserted {inserted}, skipped {skipped}", flush=True)

        custom_inserted = 0
        for c in CUSTOM_EXERCISES:
            if c["name"] in existing_names:
                continue
            row = ExerciseReference(
                external_id=None,
                name=c["name"],
                body_part=c["body_part"],
                equipment=c["equipment"],
                target_muscle=c["target_muscle"],
                secondary_muscles=[],
                instructions=[],
                gif_path=None,
                is_cult_relevant=True,
            )
            db.add(row)
            custom_inserted += 1
        await db.commit()
        print(f"Custom rows inserted: {custom_inserted}", flush=True)


if __name__ == "__main__":
    asyncio.run(seed())
