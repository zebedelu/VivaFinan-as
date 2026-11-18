"""Defaults públicos que deixam o deploy por git funcionar sem envs no painel."""

from __future__ import annotations

from app.config import DEFAULT_SUPABASE_ANON_KEY, DEFAULT_SUPABASE_URL, build_config


def test_supabase_public_defaults(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    config = build_config()

    assert config["SUPABASE_URL"] == DEFAULT_SUPABASE_URL
    assert config["SUPABASE_ANON_KEY"] == DEFAULT_SUPABASE_ANON_KEY
    # A service role é segredo: nunca tem default.
    assert config["SUPABASE_SERVICE_ROLE_KEY"] == ""


def test_env_override_wins(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://outro.supabase.co/")
    monkeypatch.setenv("SUPABASE_ANON_KEY", "chave-do-painel")

    config = build_config()

    assert config["SUPABASE_URL"] == "https://outro.supabase.co"
    assert config["SUPABASE_ANON_KEY"] == "chave-do-painel"
