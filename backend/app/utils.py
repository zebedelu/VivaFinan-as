"""Helpers de data, número e payload usados pelos endpoints."""

from __future__ import annotations

import calendar
import math
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any, Iterable, Mapping
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .errors import validation

try:
    TZ_SAO_PAULO = ZoneInfo("America/Sao_Paulo")
except ZoneInfoNotFoundError:  # pragma: no cover - depende do tzdata no host
    TZ_SAO_PAULO = timezone.utc

TIPOS = ("receita", "despesa")
ESCOPOS = ("familia", "pessoal")
STATUS_MEMBRO = ("ativo", "inativo")
TEMAS = ("claro", "escuro")


def today_sp() -> date:
    return datetime.now(TZ_SAO_PAULO).date()


def now_sp() -> datetime:
    return datetime.now(TZ_SAO_PAULO)


def parse_date(value: Any, field: str = "data") -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if not isinstance(value, str) or not value.strip():
        raise validation(f"Informe {field} no formato YYYY-MM-DD.")
    try:
        return date.fromisoformat(value.strip()[:10])
    except ValueError as exc:
        raise validation(f"{field} inválida: use YYYY-MM-DD.") from exc


def month_start(value: Any = None, field: str = "mes") -> date:
    """Aceita ``YYYY-MM``/``YYYY-MM-01``; devolve o primeiro dia."""
    if value is None or value == "":
        hoje = today_sp()
        return hoje.replace(day=1)
    if isinstance(value, (date, datetime)):
        parsed = value.date() if isinstance(value, datetime) else value
        if parsed.day != 1:
            raise validation(f"{field} precisa ser o primeiro dia do mês.")
        return parsed
    text = str(value).strip()
    if len(text) == 7:
        text = f"{text}-01"
    parsed = parse_date(text, field)
    if parsed.day != 1:
        raise validation(f"{field} precisa ser o primeiro dia do mês.")
    return parsed


def add_months(value: date, months: int) -> date:
    month = value.month - 1 + months
    year = value.year + month // 12
    month = month % 12 + 1
    day = min(value.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def last_day(value: date) -> date:
    return value.replace(day=calendar.monthrange(value.year, value.month)[1])


def month_end_exclusive(value: date) -> date:
    return add_months(value.replace(day=1), 1)


def iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def num(value: Any, default: float = 0.0) -> float:
    if value is None or isinstance(value, bool):
        return default
    if isinstance(value, str):
        text = value.strip().replace("R$", "").replace(" ", "")
        if not text:
            return default
        if "," in text:
            text = text.replace(".", "").replace(",", ".")
        try:
            parsed = float(text)
        except ValueError:
            return default
    else:
        try:
            parsed = float(value)
        except (TypeError, ValueError):
            return default
    return parsed if math.isfinite(parsed) else default


def money(value: Any, field: str = "valor") -> float:
    parsed = num(value, default=-1.0)
    if not math.isfinite(parsed) or parsed <= 0:
        raise validation(f"{field} precisa ser maior que zero.")
    return round(parsed, 2)


def opt_money(value: Any, field: str = "valor") -> float | None:
    if value is None or value == "":
        return None
    parsed = num(value, default=-1.0)
    if not math.isfinite(parsed) or parsed <= 0:
        raise validation(f"{field} precisa ser maior que zero.")
    return round(parsed, 2)


_ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def safe_id(value: Any, field: str = "id", *, max_len: int = 64) -> str:
    """Valida id usado em path/filtro do PostgREST (sem vírgula, ``&`` ou ``?``)."""
    text = str(value or "").strip()
    if not text:
        raise validation(f"Informe {field}.")
    if len(text) > max_len or not _ID_RE.match(text):
        raise validation(f"{field} inválido.")
    return text


def one_of(value: Any, allowed: Iterable[str], field: str) -> str:
    text = str(value or "").strip()
    if text not in tuple(allowed):
        raise validation(f"{field} inválido.", {"allowed": list(allowed)})
    return text


def clean_text(value: Any, field: str, *, required: bool = False, max_len: int = 200) -> str | None:
    if value is None:
        if required:
            raise validation(f"Informe {field}.")
        return None
    text = str(value).strip()
    if not text:
        if required:
            raise validation(f"Informe {field}.")
        return None
    if len(text) > max_len:
        raise validation(f"{field} excede {max_len} caracteres.")
    return text


def body() -> dict[str, Any]:
    from flask import request

    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def reject_keys(data: Mapping[str, Any], keys: Iterable[str], message: str | None = None) -> None:
    present = [key for key in keys if key in data]
    if present:
        raise validation(
            message or "Campo não aceito neste endpoint.",
            {"fields": present},
        )


def parse_int(value: Any, field: str, *, default: int | None = None, minimum: int = 0, maximum: int | None = None) -> int:
    if value is None or value == "":
        if default is None:
            raise validation(f"Informe {field}.")
        return default
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise validation(f"{field} inválido.") from exc
    if parsed < minimum:
        raise validation(f"{field} precisa ser >= {minimum}.")
    if maximum is not None and parsed > maximum:
        raise validation(f"{field} precisa ser <= {maximum}.")
    return parsed


def days_until(target: date, today: date | None = None) -> int:
    return (target - (today or today_sp())).days


def current_month() -> date:
    return today_sp().replace(day=1)


def clamp_day(year: int, month: int, day: int) -> date:
    last = calendar.monthrange(year, month)[1]
    return date(year, month, min(max(day, 1), last))


__all__ = [
    "ESCOPOS",
    "TEMAS",
    "TIPOS",
    "add_months",
    "body",
    "clamp_day",
    "clean_text",
    "current_month",
    "days_until",
    "iso",
    "last_day",
    "money",
    "month_end_exclusive",
    "month_start",
    "now_sp",
    "num",
    "one_of",
    "opt_money",
    "parse_date",
    "parse_int",
    "reject_keys",
    "safe_id",
    "today_sp",
]
