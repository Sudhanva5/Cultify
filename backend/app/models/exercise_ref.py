import uuid
from sqlalchemy import String, Boolean, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ExerciseReference(Base):
    __tablename__ = "exercise_reference"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    external_id: Mapped[str | None] = mapped_column(String(50), unique=True, nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    body_part: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    equipment: Mapped[str | None] = mapped_column(String(100), nullable=True)
    target_muscle: Mapped[str | None] = mapped_column(String(100), nullable=True)
    secondary_muscles: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    instructions: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    gif_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_cult_relevant: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
