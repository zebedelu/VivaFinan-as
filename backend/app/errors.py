"""Erros da API no formato ``{error:{code,message,details?}}``."""

from __future__ import annotations

from typing import Any


class ApiError(Exception):
    """Erro de aplicação com status HTTP e código estável."""

    def __init__(
        self,
        status: int,
        code: str,
        message: str,
        details: Any | None = None,
    ) -> None:
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
        self.details = details
        self.upstream_code: str | None = None

    def to_dict(self) -> dict[str, Any]:
        error: dict[str, Any] = {"code": self.code, "message": self.message}
        if self.details is not None:
            error["details"] = self.details
        return {"error": error}


def unavailable(feature: str, env_var: str) -> ApiError:
    return ApiError(
        503,
        "unavailable",
        f"{feature} indisponível: configure {env_var} no servidor.",
        {"feature": feature, "missing": env_var},
    )


def forbidden(message: str = "Você não tem permissão para isso.") -> ApiError:
    return ApiError(403, "forbidden", message)


def not_found(message: str = "Recurso não encontrado.") -> ApiError:
    return ApiError(404, "not_found", message)


def validation(message: str, details: Any | None = None) -> ApiError:
    return ApiError(422, "validation_error", message, details)
