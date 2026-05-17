import uuid
from datetime import datetime, date
from sqlalchemy import String, Integer, Float, Text, DateTime, Date, ForeignKey, func, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ExerciseLog(Base):
    __tablename__ = "exercise_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    exercise_ref_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("exercise_reference.id"), nullable=True)
    custom_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    sets: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reps: Mapped[int | None] = mapped_column(Integer, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)


class SleepLog(Base):
    __tablename__ = "sleep_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    slept_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    woke_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    duration_hours: Mapped[float | None] = mapped_column(Float, nullable=True)


class FoodLog(Base):
    __tablename__ = "food_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    meal_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    photo_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    estimated_calories: Mapped[float | None] = mapped_column(Float, nullable=True)
    estimated_protein_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    estimated_carbs_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    estimated_fat_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    claude_food_analysis: Mapped[str | None] = mapped_column(Text, nullable=True)


class WeightLog(Base):
    __tablename__ = "weight_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    weight_kg: Mapped[float] = mapped_column(Float, nullable=False)


class DailyAnalysis(Base):
    __tablename__ = "daily_analyses"
    __table_args__ = (UniqueConstraint("user_id", "analysis_date", name="uq_daily_analysis_user_date"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    analysis_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    day_remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    nutrition_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    weight_projection: Mapped[str | None] = mapped_column(Text, nullable=True)
    recommendations: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    full_response: Mapped[str | None] = mapped_column(Text, nullable=True)
    tokens_used: Mapped[int | None] = mapped_column(Integer, nullable=True)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    role: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
