from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings


class Base(DeclarativeBase):
    """Declarative base. Define your models against this."""


_settings = get_settings()

engine = create_async_engine(_settings.database_url, echo=False, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency. Use with `session: AsyncSession = Depends(get_session)`."""
    async with SessionLocal() as session:
        yield session


async def create_all() -> None:
    """Create tables for every model imported by the time this runs.

    Deliberately simple so the starter has no migration step. Alembic is in
    requirements.txt if you would rather use it.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
