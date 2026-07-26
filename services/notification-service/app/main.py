from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import httpx
from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

from healthcare_platform.config import RuntimeConfig

config = RuntimeConfig.from_env("notification-service")
app = FastAPI(title="Healthcare Notification Service", version="0.1.0", redoc_url=None)

ALERTS_SENT = Counter("healthcare_alerts_sent_total", "Alerts sent by severity.", ["severity"])


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "service": config.service_name}


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/notify")
async def notify(alert: dict[str, Any]) -> dict[str, Any]:
    severity = str(alert.get("severity", "info")).lower()
    webhook = _secret_value("NOTIFICATION_WEBHOOK_URL")
    delivered = False
    if webhook and not webhook.endswith(".invalid/webhook"):
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(webhook, json=alert)
            response.raise_for_status()
            delivered = True
    ALERTS_SENT.labels(severity).inc()
    return {"accepted": True, "delivered": delivered, "severity": severity}


def _secret_value(name: str) -> str | None:
    file_path = os.getenv(f"{name}_FILE")
    if file_path:
        return Path(file_path).read_text(encoding="utf-8").strip()
    return os.getenv(name)
