import uuid
from datetime import datetime, date
from typing import Any
from pydantic import BaseModel, Field


# ---------- Exercise ----------
class ExerciseLogCreate(BaseModel):
    exercise_ref_id: uuid.UUID | None = None
    custom_name: str | None = None
    sets: int | None = None
    reps: int | None = None
    weight_kg: float | None = None
    duration_minutes: int | None = None
    notes: str | None = None
    logged_at: datetime | None = None


class ExerciseLogOut(BaseModel):
    id: uuid.UUID
    exercise_ref_id: uuid.UUID | None
    custom_name: str | None
    logged_at: datetime
    sets: int | None
    reps: int | None
    weight_kg: float | None
    duration_minutes: int | None
    notes: str | None
    # joined fields
    name: str | None = None
    body_part: str | None = None
    gif_path: str | None = None

    class Config:
        from_attributes = True


# ---------- Exercise Reference ----------
class ExerciseReferenceOut(BaseModel):
    id: uuid.UUID
    name: str
    body_part: str | None
    equipment: str | None
    target_muscle: str | None
    gif_path: str | None

    class Config:
        from_attributes = True


# ---------- Sleep ----------
class SleepLogCreate(BaseModel):
    date: date
    slept_at: datetime
    woke_at: datetime


class SleepLogOut(BaseModel):
    id: uuid.UUID
    date: date
    slept_at: datetime
    woke_at: datetime
    duration_hours: float | None

    class Config:
        from_attributes = True


# ---------- Food ----------
class FoodLogOut(BaseModel):
    id: uuid.UUID
    logged_at: datetime
    meal_type: str | None
    photo_path: str | None
    description: str | None
    estimated_calories: float | None
    estimated_protein_g: float | None
    estimated_carbs_g: float | None
    estimated_fat_g: float | None
    claude_food_analysis: str | None

    class Config:
        from_attributes = True


# ---------- Weight ----------
class WeightLogCreate(BaseModel):
    weight_kg: float = Field(gt=0)
    logged_at: datetime | None = None


class WeightLogOut(BaseModel):
    id: uuid.UUID
    logged_at: datetime
    weight_kg: float

    class Config:
        from_attributes = True


# ---------- Analysis ----------
class AnalysisOut(BaseModel):
    id: uuid.UUID
    analysis_date: date
    day_remark: str | None
    nutrition_json: dict[str, Any] | None
    weight_projection: str | None
    recommendations: list[str] | None
    generated_at: datetime

    class Config:
        from_attributes = True


# ---------- Chat ----------
class ChatMessageOut(BaseModel):
    id: uuid.UUID
    role: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


class ChatResponse(BaseModel):
    response: str
    messages_used: int
    limit: int = 5


class ChatTodayResponse(BaseModel):
    messages: list[ChatMessageOut]
    messages_used: int
    limit: int = 5
