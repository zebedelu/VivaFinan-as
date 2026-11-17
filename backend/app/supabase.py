"""Clientes Supabase/PostgREST.

Leitura e escrita normais usam SEMPRE ``apikey`` anon + ``Authorization`` do
usuário. A service role fica isolada em :class:`AdminClient` e
:class:`ServiceRest`, usados apenas por convite (Admin API) e sync Pluggy.
"""

from __future__ import annotations

from typing import Any, Mapping

import httpx

from .errors import ApiError, unavailable


def _safe_message(payload: Any, fallback: str) -> str:
    if isinstance(payload, Mapping):
        message = payload.get("message") or payload.get("error_description")
        if isinstance(message, str) and message.strip():
            return message.strip()[:500]
    return fallback


# Erros do GoTrue que o admin precisa entender, traduzidos para o contrato da API.
_ADMIN_API_ERRORS: dict[str, tuple[int, str, str]] = {
    "over_email_send_rate_limit": (
        429,
        "email_rate_limited",
        "O Supabase atingiu o limite de envio de e-mails. Configure o SMTP "
        "(Authentication → Emails → SMTP) e tente de novo em alguns minutos.",
    ),
    "over_request_rate_limit": (
        429,
        "rate_limited",
        "Muitas tentativas em pouco tempo. Espere alguns minutos e tente de novo.",
    ),
    "email_exists": (409, "conflict", "Este e-mail já está cadastrado."),
    "email_address_invalid": (422, "validation_error", "E-mail inválido."),
    "signup_disabled": (403, "forbidden", "O cadastro está desabilitado neste projeto."),
    "invite_not_found": (404, "not_found", "Convite não encontrado."),
}


class SupabaseRest:
    """PostgREST com o JWT do usuário (ou service role, quando explícito)."""

    def __init__(
        self,
        base_url: str,
        api_key: str,
        jwt: str | None = None,
        *,
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.base_url = (base_url or "").rstrip("/")
        self.api_key = api_key or ""
        self.jwt = jwt or api_key or ""
        self.timeout = timeout
        self._client = httpx.Client(transport=transport, timeout=timeout)

    def close(self) -> None:
        self._client.close()

    # -- infraestrutura -------------------------------------------------
    def _headers(self, *, body: bool, prefer: str | None) -> dict[str, str]:
        headers = {
            "apikey": self.api_key,
            "Authorization": f"Bearer {self.jwt}",
            "Accept": "application/json",
        }
        if body:
            headers["Content-Type"] = "application/json"
        if prefer:
            headers["Prefer"] = prefer
        return headers

    def _error(self, response: httpx.Response) -> ApiError:
        try:
            payload = response.json()
        except ValueError:
            payload = None
        code = ""
        if isinstance(payload, Mapping):
            code = str(payload.get("code") or "")
        status = response.status_code
        if code == "PGRST116" or status == 404:
            api = ApiError(404, "not_found", "Recurso não encontrado.")
        elif code == "23505":
            api = ApiError(409, "conflict", "Registro já existe.")
        elif code in ("23503", "23514"):
            api = ApiError(422, "validation_error", "Os dados não respeitam uma regra do banco.")
        elif code in ("22023", "22P02", "22007"):
            api = ApiError(422, "validation_error", _safe_message(payload, "Dados inválidos."))
        elif code == "42501" or status == 403:
            api = ApiError(
                403,
                "forbidden",
                "Operação não permitida pelas regras de acesso.",
            )
        elif status == 401:
            api = ApiError(401, "unauthorized", "Sessão inválida ou expirada.")
        elif status == 409:
            api = ApiError(409, "conflict", _safe_message(payload, "Conflito ao gravar."))
        elif status >= 500:
            api = ApiError(503, "upstream_unavailable", "O banco de dados não respondeu.")
        else:
            api = ApiError(400, "bad_request", _safe_message(payload, "Requisição inválida."))
        api.upstream_code = code or None
        return api

    def request(
        self,
        method: str,
        path: str,
        *,
        params: Mapping[str, Any] | None = None,
        json: Any = None,
        prefer: str | None = None,
        count: bool = False,
    ) -> Any:
        url = f"{self.base_url}{path}"
        headers = self._headers(body=json is not None, prefer=prefer)
        if count:
            headers["Prefer"] = "count=exact" + (f",{prefer}" if prefer else "")
        try:
            kwargs: dict[str, Any] = {
                "json": json,
                "headers": headers,
            }
            if params is not None:
                kwargs["params"] = dict(params)
            response = self._client.request(
                method.upper(),
                url,
                **kwargs,
            )
        except httpx.HTTPError as exc:
            raise ApiError(503, "upstream_unavailable", "O banco de dados não respondeu.") from exc
        if response.status_code >= 400:
            raise self._error(response)
        if count:
            total: int | None = None
            content_range = response.headers.get("content-range", "")
            if "/" in content_range:
                try:
                    total = int(content_range.rsplit("/", 1)[1])
                except ValueError:
                    total = None
            if not response.content:
                return None, total
            try:
                data = response.json()
            except ValueError:
                data = None
            return data, total
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError:
            return None

    # -- atalhos --------------------------------------------------------
    def get(self, path: str, params: Mapping[str, Any] | None = None, *, count: bool = False) -> Any:
        return self.request("GET", path, params=params, count=count)

    def post(
        self,
        path: str,
        payload: Any,
        params: Mapping[str, Any] | None = None,
        *,
        prefer_extra: str | None = None,
        allow_empty: bool = False,
    ) -> Any:
        prefer = "return=representation"
        if prefer_extra:
            prefer = f"return=representation,{prefer_extra}"
        rows = self.request("POST", path, params=params, json=payload, prefer=prefer)
        if isinstance(rows, list) and not rows and not allow_empty:
            raise ApiError(403, "forbidden", "A operação não foi permitida pelas regras de acesso.")
        return rows

    def patch(
        self,
        path: str,
        payload: Any,
        params: Mapping[str, Any] | None = None,
        *,
        prefer_extra: str | None = None,
    ) -> Any:
        prefer = "return=representation"
        if prefer_extra:
            prefer = f"return=representation,{prefer_extra}"
        rows = self.request("PATCH", path, params=params, json=payload, prefer=prefer)
        if isinstance(rows, list) and not rows:
            raise ApiError(404, "not_found", "Registro não encontrado ou sem permissão.")
        return rows

    def delete(self, path: str, params: Mapping[str, Any] | None = None) -> Any:
        rows = self.request(
            "DELETE",
            path,
            params=params,
            prefer="return=representation",
        )
        if isinstance(rows, list) and not rows:
            raise ApiError(404, "not_found", "Registro não encontrado ou sem permissão.")
        return rows

    def rpc(self, name: str, payload: Mapping[str, Any] | None = None) -> Any:
        return self.request("POST", f"/rest/v1/rpc/{name}", json=dict(payload or {}))


class SupabaseAuth:
    """Validação do Bearer em ``GET /auth/v1/user``."""

    def __init__(
        self,
        base_url: str,
        anon_key: str,
        *,
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.base_url = (base_url or "").rstrip("/")
        self.anon_key = anon_key or ""
        self.timeout = timeout
        self._client = httpx.Client(transport=transport, timeout=timeout)

    def close(self) -> None:
        self._client.close()

    def get_user(self, token: str) -> dict[str, Any]:
        if not self.base_url or not self.anon_key:
            raise unavailable("Autenticação", "SUPABASE_URL/SUPABASE_ANON_KEY")
        try:
            response = self._client.get(
                f"{self.base_url}/auth/v1/user",
                headers={
                    "apikey": self.anon_key,
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                },
            )
        except httpx.HTTPError as exc:
            raise ApiError(503, "upstream_unavailable", "A autenticação não respondeu.") from exc
        if response.status_code == 401:
            raise ApiError(401, "unauthorized", "Sessão inválida ou expirada.")
        if response.status_code >= 400:
            raise ApiError(401, "unauthorized", "Sessão inválida ou expirada.")
        try:
            payload = response.json()
        except ValueError as exc:
            raise ApiError(401, "unauthorized", "Sessão inválida ou expirada.") from exc
        if not isinstance(payload, dict) or not payload.get("id"):
            raise ApiError(401, "unauthorized", "Sessão inválida ou expirada.")
        return payload


class ServiceRest(SupabaseRest):
    """PostgREST com service role. Uso restrito a sync/seed."""

    @classmethod
    def from_config(cls, config: Mapping[str, Any]) -> "ServiceRest":
        key = (config.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
        if not key:
            raise unavailable("Operação administrativa", "SUPABASE_SERVICE_ROLE_KEY")
        return cls(
            config.get("SUPABASE_URL", ""),
            key,
            key,
            transport=config.get("HTTP_TRANSPORT"),
            timeout=float(config.get("HTTP_TIMEOUT", 10.0)),
        )


class AdminClient:
    """Admin API do Supabase Auth (convite e cancelamento)."""

    def __init__(
        self,
        base_url: str,
        service_key: str,
        *,
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.base_url = (base_url or "").rstrip("/")
        self.service_key = service_key or ""
        self.timeout = timeout
        self._client = httpx.Client(transport=transport, timeout=timeout)

    def close(self) -> None:
        self._client.close()

    @classmethod
    def from_config(cls, config: Mapping[str, Any]) -> "AdminClient":
        key = (config.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
        if not key:
            raise unavailable("Admin API", "SUPABASE_SERVICE_ROLE_KEY")
        return cls(
            config.get("SUPABASE_URL", ""),
            key,
            transport=config.get("HTTP_TRANSPORT"),
            timeout=float(config.get("HTTP_TIMEOUT", 10.0)),
        )

    def _request(self, method: str, path: str, json: Any = None) -> Any:
        try:
            response = self._client.request(
                method,
                f"{self.base_url}{path}",
                json=json,
                headers={
                    "apikey": self.service_key,
                    "Authorization": f"Bearer {self.service_key}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
            )
        except httpx.HTTPError as exc:
            raise ApiError(503, "upstream_unavailable", "A Admin API não respondeu.") from exc
        if response.status_code >= 400:
            try:
                payload = response.json()
            except ValueError:
                payload = None
            error_code = str((payload or {}).get("error_code") or "") if isinstance(payload, Mapping) else ""
            if error_code in _ADMIN_API_ERRORS:
                status, code, message = _ADMIN_API_ERRORS[error_code]
                raise ApiError(status, code, message)
            message = _safe_message(payload, "A Admin API recusou a operação.")
            if response.status_code == 404:
                raise ApiError(404, "not_found", "Recurso não encontrado na Admin API.")
            if response.status_code == 429:
                raise ApiError(
                    429,
                    "rate_limited",
                    "O Supabase recusou por limite de requisições. Tente de novo em instantes.",
                )
            if response.status_code == 422:
                raise ApiError(409, "conflict", "Este e-mail já está cadastrado.", {"message": message})
            if response.status_code == 401 or response.status_code == 403:
                raise unavailable("Admin API", "SUPABASE_SERVICE_ROLE_KEY")
            raise ApiError(502, "upstream_error", message)
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError:
            return None

    def invite_user(
        self,
        email: str,
        data: Mapping[str, Any] | None = None,
        redirect_to: str | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {"email": email}
        if data:
            payload["data"] = dict(data)
        if redirect_to:
            payload["redirect_to"] = redirect_to
        result = self._request("POST", "/auth/v1/invite", payload)
        return result if isinstance(result, dict) else {}

    def delete_user(self, user_id: str) -> None:
        try:
            self._request("DELETE", f"/auth/v1/admin/users/{user_id}")
        except ApiError as exc:
            if exc.status != 404:
                raise
