"""Validação de payloads (sem queries)."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import validation
from ..utils import clean_text


def require_text(data: Mapping[str, Any], field: str, *, max_len: int = 200) -> str:
    value = clean_text(data.get(field), field, required=True, max_len=max_len)
    assert value is not None
    return value


def reject(data: Mapping[str, Any], fields: tuple[str, ...], message: str) -> None:
    present = [field for field in fields if field in data]
    if present:
        raise validation(message, {"fields": present})
