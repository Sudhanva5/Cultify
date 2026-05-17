"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-17 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto"')

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "exercise_reference",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("external_id", sa.String(50), nullable=True, unique=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("body_part", sa.String(100), nullable=True),
        sa.Column("equipment", sa.String(100), nullable=True),
        sa.Column("target_muscle", sa.String(100), nullable=True),
        sa.Column("secondary_muscles", postgresql.JSONB, nullable=True),
        sa.Column("instructions", postgresql.JSONB, nullable=True),
        sa.Column("gif_path", sa.Text, nullable=True),
        sa.Column("is_cult_relevant", sa.Boolean, server_default=sa.text("TRUE"), nullable=False),
    )
    op.create_index("ix_exercise_reference_external_id", "exercise_reference", ["external_id"], unique=True)
    op.create_index("ix_exercise_reference_body_part", "exercise_reference", ["body_part"])

    op.create_table(
        "exercise_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("exercise_ref_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("exercise_reference.id"), nullable=True),
        sa.Column("custom_name", sa.String(200), nullable=True),
        sa.Column("logged_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("sets", sa.Integer, nullable=True),
        sa.Column("reps", sa.Integer, nullable=True),
        sa.Column("weight_kg", sa.Float, nullable=True),
        sa.Column("duration_minutes", sa.Integer, nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
    )
    op.create_index("ix_exercise_logs_user_id", "exercise_logs", ["user_id"])

    op.create_table(
        "sleep_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("slept_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("woke_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_hours", sa.Float, nullable=True),
    )
    op.create_index("ix_sleep_logs_user_id", "sleep_logs", ["user_id"])
    op.create_index("ix_sleep_logs_date", "sleep_logs", ["date"])

    op.create_table(
        "food_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("logged_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("meal_type", sa.String(20), nullable=True),
        sa.Column("photo_path", sa.Text, nullable=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("estimated_calories", sa.Float, nullable=True),
        sa.Column("estimated_protein_g", sa.Float, nullable=True),
        sa.Column("estimated_carbs_g", sa.Float, nullable=True),
        sa.Column("estimated_fat_g", sa.Float, nullable=True),
        sa.Column("claude_food_analysis", sa.Text, nullable=True),
    )
    op.create_index("ix_food_logs_user_id", "food_logs", ["user_id"])

    op.create_table(
        "weight_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("logged_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("weight_kg", sa.Float, nullable=False),
    )
    op.create_index("ix_weight_logs_user_id", "weight_logs", ["user_id"])

    op.create_table(
        "daily_analyses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("analysis_date", sa.Date, nullable=False),
        sa.Column("day_remark", sa.Text, nullable=True),
        sa.Column("nutrition_json", postgresql.JSONB, nullable=True),
        sa.Column("weight_projection", sa.Text, nullable=True),
        sa.Column("recommendations", postgresql.JSONB, nullable=True),
        sa.Column("full_response", sa.Text, nullable=True),
        sa.Column("tokens_used", sa.Integer, nullable=True),
        sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "analysis_date", name="uq_daily_analysis_user_date"),
    )
    op.create_index("ix_daily_analyses_user_id", "daily_analyses", ["user_id"])
    op.create_index("ix_daily_analyses_analysis_date", "daily_analyses", ["analysis_date"])

    op.create_table(
        "chat_messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("role", sa.String(10), nullable=False),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("date", sa.Date, nullable=False),
    )
    op.create_index("ix_chat_messages_user_id", "chat_messages", ["user_id"])
    op.create_index("ix_chat_messages_date", "chat_messages", ["date"])


def downgrade() -> None:
    op.drop_table("chat_messages")
    op.drop_table("daily_analyses")
    op.drop_table("weight_logs")
    op.drop_table("food_logs")
    op.drop_table("sleep_logs")
    op.drop_table("exercise_logs")
    op.drop_table("exercise_reference")
    op.drop_table("users")
