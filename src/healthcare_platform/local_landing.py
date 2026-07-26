from __future__ import annotations

from pathlib import Path

from healthcare_platform.cloud_events import serialize_event
from healthcare_platform.contracts import SourceType


def write_local_outbox(base_path: Path, source_type: SourceType, event: dict) -> Path:
    target_dir = base_path / source_type.value
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / "events.jsonl"
    with target_file.open("ab") as handle:
        handle.write(serialize_event(event))
        handle.write(b"\n")
    return target_file
