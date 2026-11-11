"""Configuração do backend a partir do ambiente.

Nenhuma credencial tem default real: chaves vazias desabilitam o recurso
correspondente (IA cai para fallback, Pluggy/Admin/restore devolvem 503).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Mapping

DEFAULT_CORS = "http://localhost:5173,http://127.0.0.1:5173"
DEFAULT_DEMO_FAMILY_ID = "eeeeeeee-0000-4000-8000-000000000001"

_BACKEND_ROOT = Path(__file__).resolve().parents[1]
_DEFAULT_SEED_DIR = _BACKEND_ROOT / "seed"


def _env(name: str, default: str = "") -> str:
    return (os.environ.get(name) or default).strip()


def _seed_dir(value: str = "") -> str:
    """Resolve ``SEED_DIR``; o default é ``backend/seed`` (cópia do seed canônico).

    Caminhos absolutos passam direto. Relativos são tentados primeiro a partir de
    ``backend/`` (layout do deploy, onde ``SEED_DIR=seed``) e depois a partir do
    cwd (permite ``SEED_DIR=supabase/seed`` rodando da raiz do repositório).
    """
    raw = Path(value or _DEFAULT_SEED_DIR)
    if raw.is_absolute():
        return str(raw)
    backend_relative = _BACKEND_ROOT / raw
    if backend_relative.is_dir() or not (Path.cwd() / raw).is_dir():
        return str(backend_relative)
    return str(Path.cwd() / raw)


def _origins(value: Any) -> list[str]:
    if isinstance(value, (list, tuple)):
        return [str(item).strip() for item in value if str(item).strip()]
    return [item.strip() for item in str(value or "").split(",") if item.strip()]


def build_config(overrides: Mapping[str, Any] | None = None) -> dict[str, Any]:
    config: dict[str, Any] = {
        "SUPABASE_URL": _env("SUPABASE_URL").rstrip("/"),
        "SUPABASE_ANON_KEY": _env("SUPABASE_ANON_KEY"),
        "SUPABASE_SERVICE_ROLE_KEY": _env("SUPABASE_SERVICE_ROLE_KEY"),
        "SUPABASE_DB_URL": _env("SUPABASE_DB_URL"),
        "PLUGGY_API_KEY": _env("PLUGGY_API_KEY"),
        "PLUGGY_BASE_URL": _env("PLUGGY_BASE_URL", "https://api.pluggy.ai").rstrip("/"),
        "JEV_AI_BASE_URL": _env("JEV_AI_BASE_URL"),
        "JEV_AI_API_KEY": _env("JEV_AI_API_KEY"),
        "CORS_ORIGINS": _origins(_env("CORS_ORIGINS", DEFAULT_CORS)),
        "DEMO_FAMILY_ID": _env("DEMO_FAMILY_ID", DEFAULT_DEMO_FAMILY_ID),
        "SEED_DIR": _seed_dir(_env("SEED_DIR")),
        "HTTP_TIMEOUT": 10.0,
        "HTTP_TRANSPORT": None,
        "AI_TRANSPORT": None,
        "AI_SERVICE": None,
        "TESTING": False,
    }
    if overrides:
        config.update(overrides)
    if isinstance(config.get("CORS_ORIGINS"), str):
        config["CORS_ORIGINS"] = _origins(config["CORS_ORIGINS"])
    return config
