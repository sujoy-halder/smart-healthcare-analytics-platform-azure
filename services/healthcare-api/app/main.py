from __future__ import annotations

import os
from typing import Any

from fastapi import FastAPI, HTTPException, Response, status
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from healthcare_platform.cloud_events import build_cloud_event, serialize_event
from healthcare_platform.config import RuntimeConfig
from healthcare_platform.contracts import parse_source_type
from healthcare_platform.local_landing import write_local_outbox
from healthcare_platform.masking import deidentify_record
from healthcare_platform.quality import quality_score, validate_record

try:
    from azure.eventhub import EventData
    from azure.eventhub.aio import EventHubProducerClient
    from azure.identity.aio import DefaultAzureCredential
except ImportError:  # pragma: no cover - dependency is present in the container image
    EventData = None
    EventHubProducerClient = None
    DefaultAzureCredential = None


config = RuntimeConfig.from_env("healthcare-api")
app = FastAPI(
    title="Smart Healthcare Ingestion API",
    version="0.1.0",
    docs_url="/docs" if config.environment != "prod" else None,
    redoc_url=None,
)

INGESTED = Counter(
    "healthcare_ingested_records_total",
    "Number of records accepted by source type.",
    ["source_type"],
)
REJECTED = Counter(
    "healthcare_rejected_records_total",
    "Number of records rejected by source type.",
    ["source_type"],
)
LATENCY = Histogram(
    "healthcare_ingest_latency_seconds",
    "Ingestion request latency by source type.",
    ["source_type"],
)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "service": config.service_name, "environment": config.environment}


@app.get("/readyz")
def readyz() -> dict[str, str]:
    return {"status": "ready"}


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/ingest/{source_type}", status_code=status.HTTP_202_ACCEPTED)
async def ingest(source_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    try:
        parsed_source_type = parse_source_type(source_type)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    with LATENCY.labels(parsed_source_type.value).time():
        result = validate_record(parsed_source_type, payload)
        if not result.valid:
            REJECTED.labels(parsed_source_type.value).inc()
            raise HTTPException(status_code=422, detail=result.as_dict())

        event = build_cloud_event(
            parsed_source_type,
            deidentify_record(payload, config.identifier_salt),
        )
        await _publish_or_land(parsed_source_type.value, event)
        INGESTED.labels(parsed_source_type.value).inc()
        return {
            "accepted": True,
            "source_type": parsed_source_type.value,
            "event_id": event["id"],
            "quality_score": quality_score(result),
        }


async def _publish_or_land(source_type: str, event: dict[str, Any]) -> None:
    namespace = os.getenv("EVENTHUB_NAMESPACE")
    hub_name = os.getenv(f"EVENTHUB_{source_type.upper()}")

    if namespace and hub_name and EventHubProducerClient and DefaultAzureCredential:
        credential = DefaultAzureCredential()
        fully_qualified_namespace = f"{namespace}.servicebus.windows.net"
        producer = EventHubProducerClient(
            fully_qualified_namespace=fully_qualified_namespace,
            eventhub_name=hub_name,
            credential=credential,
        )
        async with credential, producer:
            batch = await producer.create_batch()
            batch.add(EventData(body=serialize_event(event)))
            await producer.send_batch(batch)
        return

    write_local_outbox(config.local_outbox_path, parse_source_type(source_type), event)
