"""Garante que a cópia de ``backend/seed`` não diverge do seed canônico."""

from __future__ import annotations

from pathlib import Path

from app.config import build_config
from app.services.demo_restore import SEED_PREFIXES

REPO_ROOT = Path(__file__).resolve().parents[2]
CANONICAL_SEED_DIR = REPO_ROOT / "supabase" / "seed"
BACKEND_SEED_DIR = REPO_ROOT / "backend" / "seed"


def test_backend_seed_mirrors_supabase_seed():
    for prefix in SEED_PREFIXES:
        canonical = sorted(CANONICAL_SEED_DIR.glob(f"{prefix}_*.sql"))
        assert canonical, f"seed canônico {prefix} ausente em supabase/seed"

        mirrored = {path.name: path for path in BACKEND_SEED_DIR.glob(f"{prefix}_*.sql")}
        assert mirrored, f"seed {prefix} ausente em backend/seed"
        for source in canonical:
            copy = mirrored.get(source.name)
            assert copy is not None, f"backend/seed/{source.name} ausente"
            assert copy.read_bytes() == source.read_bytes(), (
                f"backend/seed/{source.name} divergiu de supabase/seed/{source.name}; "
                "copie o arquivo canônico de novo."
            )


def test_default_seed_dir_points_to_backend_seed(monkeypatch):
    monkeypatch.delenv("SEED_DIR", raising=False)
    config = build_config()
    assert Path(config["SEED_DIR"]) == BACKEND_SEED_DIR
