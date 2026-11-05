"""Fábrica da aplicação Flask."""

from __future__ import annotations

import logging
from typing import Any, Mapping

from flask import Flask, g, jsonify
from flask_cors import CORS
from werkzeug.exceptions import HTTPException

from .config import build_config
from .errors import ApiError


def create_app(overrides: Mapping[str, Any] | None = None) -> Flask:
    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ImportError:  # pragma: no cover - dependência declarada
        pass

    app = Flask(__name__)
    app.config.update(build_config(overrides))
    app.json.sort_keys = False

    origins = app.config.get("CORS_ORIGINS") or []
    CORS(
        app,
        resources={r"/api/*": {"origins": origins}},
        allow_headers=["Authorization", "Content-Type", "Accept"],
        methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    )

    from .blueprints.admin import bp as admin_bp
    from .blueprints.ai import bp as ai_bp
    from .blueprints.banking import bp as banking_bp
    from .blueprints.demo import bp as demo_bp
    from .blueprints.family import bp as family_bp
    from .blueprints.forecast import bp as forecast_bp
    from .blueprints.goals import bp as goals_bp
    from .blueprints.health import bp as health_bp
    from .blueprints.me import bp as me_bp
    from .blueprints.recurring import bp as recurring_bp
    from .blueprints.transactions import bp as transactions_bp

    for blueprint in (
        health_bp,
        me_bp,
        family_bp,
        transactions_bp,
        recurring_bp,
        goals_bp,
        forecast_bp,
        ai_bp,
        banking_bp,
        admin_bp,
        demo_bp,
    ):
        app.register_blueprint(blueprint)

    register_error_handlers(app)

    @app.teardown_appcontext
    def close_http_clients(_exc: BaseException | None = None) -> None:
        for attribute in ("_rest_client", "_auth_client"):
            client = getattr(g, attribute, None)
            if client is not None:
                try:
                    client.close()
                except Exception:  # pragma: no cover - fechamento defensivo
                    pass

    return app


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(ApiError)
    def handle_api_error(exc: ApiError):
        return jsonify(exc.to_dict()), exc.status

    @app.errorhandler(HTTPException)
    def handle_http_error(exc: HTTPException):
        code = "not_found" if exc.code == 404 else "http_error"
        return (
            jsonify({"error": {"code": code, "message": exc.description or "Erro na requisição."}}),
            exc.code or 500,
        )

    @app.errorhandler(Exception)
    def handle_unexpected(exc: Exception):  # pragma: no cover - caminho de falha
        logging.getLogger(__name__).exception("Erro inesperado na API")
        return (
            jsonify(
                {
                    "error": {
                        "code": "internal_error",
                        "message": "Algo deu errado no servidor.",
                    }
                }
            ),
            500,
        )
