from __future__ import annotations

import argparse
import json
import os
import time
from collections.abc import Iterable
from contextlib import suppress
from pathlib import Path

from healthcare_platform.config import RuntimeConfig
from healthcare_platform.contracts import SourceType, parse_source_type
from healthcare_platform.local_landing import write_local_outbox

try:
    from azure.identity import DefaultAzureCredential
    from azure.storage.filedatalake import DataLakeServiceClient
except ImportError:  # pragma: no cover - dependency is present in the container image
    DefaultAzureCredential = None
    DataLakeServiceClient = None


config = RuntimeConfig.from_env("etl-service")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--healthcheck", action="store_true")
    parser.add_argument("--source-type", default="ehr")
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    if args.healthcheck:
        print("ok")
        return

    source_type = parse_source_type(args.source_type)
    while True:
        processed = land_local_events(source_type)
        print(json.dumps({"source_type": source_type.value, "processed_files": processed}))
        if args.once:
            return
        time.sleep(int(os.getenv("ETL_POLL_SECONDS", "30")))


def land_local_events(source_type: SourceType) -> int:
    files = list(_input_files(config.local_outbox_path / source_type.value))
    for file_path in files:
        event = json.loads(file_path.read_text(encoding="utf-8").splitlines()[-1])
        if not _write_to_adls(source_type, event):
            write_local_outbox(config.local_outbox_path / "bronze_landing", source_type, event)
    return len(files)


def _input_files(path: Path) -> Iterable[Path]:
    if not path.exists():
        return []
    return path.glob("*.jsonl")


def _write_to_adls(source_type: SourceType, event: dict) -> bool:
    account_name = os.getenv("ADLS_ACCOUNT_NAME")
    filesystem = os.getenv("ADLS_BRONZE_FILESYSTEM", "bronze")
    if not account_name or not DataLakeServiceClient or not DefaultAzureCredential:
        return False

    credential = DefaultAzureCredential()
    service_client = DataLakeServiceClient(
        account_url=f"https://{account_name}.dfs.core.windows.net",
        credential=credential,
    )
    file_system_client = service_client.get_file_system_client(filesystem)
    directory = file_system_client.get_directory_client(source_type.value)
    with suppress(Exception):
        directory.create_directory()

    file_client = directory.get_file_client(f"{event['id']}.json")
    payload = json.dumps(event, sort_keys=True).encode("utf-8")
    file_client.upload_data(payload, overwrite=True)
    return True


if __name__ == "__main__":
    main()
