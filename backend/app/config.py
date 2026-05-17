from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str
    SECRET_KEY: str
    ANTHROPIC_API_KEY: str
    GOOGLE_SERVICE_ACCOUNT_JSON: str = ""
    GOOGLE_SHARE_EMAIL: str = ""
    UPLOAD_DIR: str = "uploads"
    STATIC_DIR: str = "static"
    PORT: int = 8000

    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_DAYS: int = 30
    CLAUDE_MODEL: str = "claude-sonnet-4-5"


settings = Settings()
