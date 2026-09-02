import uuid
from pathlib import Path

from app.config import get_settings


def storage_root() -> Path:
    root = get_settings().storage_dir
    root.mkdir(parents=True, exist_ok=True)
    return root


def new_storage_dir(prefix: str = "upload") -> Path:
    """Allocate an empty directory under the storage root and return it."""
    path = storage_root() / f"{prefix}-{uuid.uuid4().hex}"
    path.mkdir(parents=True, exist_ok=False)
    return path
