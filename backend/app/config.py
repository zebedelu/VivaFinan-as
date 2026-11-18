"""Configuração do backend a partir do ambiente.

Nenhuma credencial tem default real: chaves vazias desabilitam o recurso
correspondente (IA cai para fallback, Pluggy/Admin/restore devolvem 503).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Mapping

DEFAULT_CORS = (
    "https://trabalho-terceiro-trimestre-vivafinancas.vercel.app,"
    "http://localhost:5173,http://127.0.0.1:5173,"
    # WebView do Capacitor (Etapa 6): a origem não é o domínio da Vercel.
    "https://localhost,capacitor://localhost"
)
DEFAULT_DEMO_FAMILY_ID = "eeeeeeee-0000-4000-8000-000000000001"
DEFAULT_PUBLIC_SITE_URL = "https://trabalho-terceiro-trimestre-vivafinancas.vercel.app"
DEFAULT_AI_MODEL = "deepseek-v4.1-flash"
# Projeto Supabase da entrega. URL e anon key são públicas (vão no bundle do
# frontend em `frontend/.env.production`); envs do painel têm precedência.
DEFAULT_SUPABASE_URL = "https://pqxfeyuutkkqavhnysus.supabase.co"
DEFAULT_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxeGZleXV1dGtrcWF2aG55c3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM3MjkzNTUsImV4cCI6MjEwOTMwNTM1NX0.8aMKan6S-vk7VLFwF3S55XlPHwViCxqJ3tJjKnbuaBw"

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


def _number(name: str, default: float) -> float:
    try:
        return float(_env(name) or default)
    except ValueError:
        return default


def _origins(value: Any) -> list[str]:
    if isinstance(value, (list, tuple)):
        return [str(item).strip() for item in value if str(item).strip()]
    return [item.strip() for item in str(value or "").split(",") if item.strip()]


def build_config(overrides: Mapping[str, Any] | None = None) -> dict[str, Any]:
    config: dict[str, Any] = {
        "SUPABASE_URL": _env("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/"),
        "SUPABASE_ANON_KEY": _env("SUPABASE_ANON_KEY", DEFAULT_SUPABASE_ANON_KEY),
        "SUPABASE_SERVICE_ROLE_KEY": _env("SUPABASE_SERVICE_ROLE_KEY"),
        "SUPABASE_DB_URL": _env("SUPABASE_DB_URL"),
        "PLUGGY_API_KEY": _env("PLUGGY_API_KEY"),
        "PLUGGY_CLIENT_ID": _env("PLUGGY_CLIENT_ID"),
        "PLUGGY_CLIENT_SECRET": _env("PLUGGY_CLIENT_SECRET"),
        "PLUGGY_WEBHOOK_SECRET": _env("PLUGGY_WEBHOOK_SECRET"),
        "PLUGGY_BASE_URL": _env("PLUGGY_BASE_URL", "https://api.pluggy.ai").rstrip("/"),
        "JEV_AI_BASE_URL": _env("JEV_AI_BASE_URL"),
        "JEV_AI_API_KEY": _env("JEV_AI_API_KEY"),
        "JEV_AI_MODEL": _env("JEV_AI_MODEL", DEFAULT_AI_MODEL),
        "JEV_AI_PROVIDER": _env("JEV_AI_PROVIDER"),
        "JEV_AI_SESSION": _env("JEV_AI_SESSION"),
        "JEV_AI_TIMEOUT": _number("JEV_AI_TIMEOUT", 75.0),
        "PUBLIC_SITE_URL": _env("PUBLIC_SITE_URL", DEFAULT_PUBLIC_SITE_URL).rstrip("/"),
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
