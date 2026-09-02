from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db import create_all, get_session
from app.storage import storage_root

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    storage_root()
    await create_all()
    yield


app = FastAPI(title="Starter", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health(session: AsyncSession = Depends(get_session)) -> dict[str, object]:
    await session.execute(text("SELECT 1"))
    return {
        "status": "ok",
        "database": "connected",
        "storage_dir": str(settings.storage_dir),
    }


# Build the feature here. Routers, models, and background work are all yours.
