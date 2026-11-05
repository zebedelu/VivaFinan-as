"""Restauração da demo via Postgres direto (``SUPABASE_DB_URL``)."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Mapping

from ..errors import ApiError, unavailable

logger = logging.getLogger(__name__)

SEED_PREFIXES = ("010", "020", "030", "040")


def seed_files(seed_dir: str | Path) -> list[Path]:
    directory = Path(seed_dir)
    files: list[Path] = []
    for prefix in SEED_PREFIXES:
        matches = sorted(directory.glob(f"{prefix}_*.sql"))
        if not matches:
            raise ApiError(
                503,
                "seed_missing",
                f"Seed {prefix} não encontrado em SEED_DIR.",
            )
        files.extend(matches)
    return files


def restore(config: Mapping[str, Any]) -> dict[str, Any]:
    db_url = (config.get("SUPABASE_DB_URL") or "").strip()
    if not db_url:
        raise unavailable("Restauração da demo", "SUPABASE_DB_URL")
    files = seed_files(config.get("SEED_DIR") or "")
    try:
        import psycopg
    except ImportError as exc:  # pragma: no cover - dependência declarada
        raise unavailable("Restauração da demo", "psycopg") from exc

    statements = [path.read_text(encoding="utf-8") for path in files]
    try:
        with psycopg.connect(db_url, connect_timeout=10) as connection:
            with connection.transaction():
                with connection.cursor() as cursor:
                    for sql in statements:
                        cursor.execute(sql)
    except Exception as exc:
        logger.warning("Restauração da demo falhou: %s", type(exc).__name__)
        raise ApiError(502, "restore_failed", "Não foi possível restaurar a demonstração.") from exc
    return {"ok": True, "seeds": len(statements)}
