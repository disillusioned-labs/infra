"""Idempotently provision the Disillusioned Labs Uptime Kuma monitors."""

from __future__ import annotations

import os
import sys
import time
import traceback
from typing import Any

from uptime_kuma_api import DockerType, MonitorType, UptimeKumaApi


KUMA_URL = os.getenv("KUMA_URL", "http://uptime-kuma:3001")
KUMA_USERNAME = os.getenv("KUMA_USERNAME", "admin")
KUMA_PASSWORD = os.getenv("KUMA_PASSWORD", "")

COMMON: dict[str, Any] = {
    "interval": 60,
    "retryInterval": 20,
    "maxretries": 2,
    "resendInterval": 0,
}

GROUPS = (
    {"name": "Disillusioned Labs", "type": MonitorType.GROUP},
    {
        "name": "Application endpoints",
        "type": MonitorType.GROUP,
        "parent_name": "Disillusioned Labs",
    },
    {
        "name": "Infrastructure endpoints",
        "type": MonitorType.GROUP,
        "parent_name": "Disillusioned Labs",
    },
    {
        "name": "Background services",
        "type": MonitorType.GROUP,
        "parent_name": "Disillusioned Labs",
    },
)

# Kuma is attached to the same Compose networks, so these checks validate the
# actual container listeners instead of depending on host port forwarding.
ENDPOINT_MONITORS = (
    {
        "name": "Identity API (8080)",
        "type": MonitorType.HTTP,
        "url": "http://identity-api:8080/readyz",
        "parent_name": "Application endpoints",
    },
    {
        "name": "Expense API (8081)",
        "type": MonitorType.HTTP,
        "url": "http://expense-api:8081/readyz",
        "parent_name": "Application endpoints",
    },
    {
        "name": "Expense gRPC (9091)",
        "type": MonitorType.PORT,
        "hostname": "expense-grpc",
        "port": 9091,
        "parent_name": "Application endpoints",
    },
    {
        "name": "OCR Gateway (8083)",
        "type": MonitorType.HTTP,
        "url": "http://ocr-gateway-grpc:8083/readyz",
        "parent_name": "Application endpoints",
    },
    {
        "name": "OCR Gateway gRPC (9093)",
        "type": MonitorType.PORT,
        "hostname": "ocr-gateway-grpc",
        "port": 9093,
        "parent_name": "Application endpoints",
    },
    {
        "name": "OCR Engine gRPC (9094)",
        "type": MonitorType.PORT,
        "hostname": "ocr-grpc",
        "port": 9094,
        "parent_name": "Application endpoints",
    },
    {
        "name": "PostgreSQL (5432)",
        "type": MonitorType.PORT,
        "hostname": "data-postgres",
        "port": 5432,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Redis (6379)",
        "type": MonitorType.PORT,
        "hostname": "data-redis",
        "port": 6379,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "PgAdmin (5050)",
        "type": MonitorType.HTTP,
        "url": "http://data-pgadmin:80/",
        "accepted_statuscodes": ["200-299", "300-399"],
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "RedisInsight (5540)",
        "type": MonitorType.HTTP,
        "url": "http://data-redisinsight:5540/",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "SeaweedFS S3 (8333)",
        "type": MonitorType.PORT,
        "hostname": "data-seaweedfs",
        "port": 8333,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "SeaweedFS Admin (23646)",
        "type": MonitorType.PORT,
        "hostname": "data-seaweedfs",
        "port": 23646,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Kafka external listener (19092)",
        "type": MonitorType.PORT,
        "hostname": "messaging-kafka",
        "port": 19092,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Kafka UI (3001)",
        "type": MonitorType.HTTP,
        "url": "http://messaging-kafka-ui:8080/",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Grafana (3000)",
        "type": MonitorType.HTTP,
        "url": "http://grafana:3000/api/health",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Loki (3100)",
        "type": MonitorType.HTTP,
        "url": "http://loki:3100/ready",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Tempo (3200)",
        "type": MonitorType.HTTP,
        "url": "http://tempo:3200/ready",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "Mimir (9009)",
        "type": MonitorType.HTTP,
        "url": "http://mimir:9009/ready",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "OTel OTLP gRPC (4317)",
        "type": MonitorType.PORT,
        "hostname": "otel-collector",
        "port": 4317,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "OTel OTLP HTTP (4318)",
        "type": MonitorType.PORT,
        "hostname": "otel-collector",
        "port": 4318,
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "OTel metrics (8888)",
        "type": MonitorType.HTTP,
        "url": "http://otel-collector:8888/metrics",
        "parent_name": "Infrastructure endpoints",
    },
    {
        "name": "OTel health (13133)",
        "type": MonitorType.HTTP,
        "url": "http://otel-collector:13133/",
        "parent_name": "Infrastructure endpoints",
    },
)

BACKGROUND_CONTAINERS = (
    "audit-consumer",
    "identity-worker",
    "expense-consumer",
    "expense-worker",
    "ocr-api",
    "ocr-worker",
    "ocr-outbox",
    "notification-consumer-transactional",
    "notification-consumer-social",
    "notification-consumer-marketing",
    "notification-worker",
)


def connect() -> UptimeKumaApi:
    """Wait for Kuma because Podman Compose health conditions vary by provider."""
    last_error: Exception | None = None
    for _ in range(30):
        try:
            return UptimeKumaApi(KUMA_URL, timeout=10)
        except Exception as error:  # The library exposes several transport errors.
            last_error = error
            time.sleep(2)
    raise RuntimeError(f"Uptime Kuma did not become ready: {last_error!r}") from last_error


def monitor_index(api: UptimeKumaApi) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    duplicates: set[str] = set()
    for monitor in api.get_monitors():
        name = monitor["name"]
        if name in index:
            duplicates.add(name)
        index[name] = monitor
    if duplicates:
        names = ", ".join(sorted(duplicates))
        raise RuntimeError(f"duplicate Kuma monitor names must be resolved first: {names}")
    return index


def upsert_monitor(
    api: UptimeKumaApi,
    definition: dict[str, Any],
    parents: dict[str, int],
) -> int:
    desired = dict(COMMON)
    desired.update(definition)
    parent_name = desired.pop("parent_name", None)
    if parent_name:
        desired["parent"] = parents[parent_name]

    try:
        existing = monitor_index(api).get(desired["name"])
        if existing:
            api.edit_monitor(existing["id"], **desired)
            action = "updated"
            monitor_id = existing["id"]
        else:
            result = api.add_monitor(**desired)
            action = "created"
            monitor_id = result["monitorID"]
    except Exception as error:
        raise RuntimeError(
            f"failed to upsert Uptime Kuma monitor {desired['name']!r}: "
            f"{type(error).__name__}({error!r})"
        ) from error

    print(f"{action:7} #{monitor_id:<3} {desired['name']}")
    return monitor_id


def ensure_docker_host(api: UptimeKumaApi) -> int:
    name = "Local Podman"
    daemon = "tcp://podman-socket-proxy:2375"
    matching = [host for host in api.get_docker_hosts() if host["name"] == name]
    if len(matching) > 1:
        raise RuntimeError(f"duplicate Kuma Docker hosts named {name!r}")
    if matching:
        host_id = matching[0]["id"]
        api.edit_docker_host(
            host_id,
            name=name,
            dockerType=DockerType.TCP,
            dockerDaemon=daemon,
        )
        return host_id
    result = api.add_docker_host(
        name=name,
        dockerType=DockerType.TCP,
        dockerDaemon=daemon,
    )
    return result["id"]


def main() -> None:
    if not KUMA_PASSWORD:
        raise RuntimeError("KUMA_PASSWORD is required; copy .env.example to .env")

    api = connect()
    try:
        if api.need_setup():
            api.setup(KUMA_USERNAME, KUMA_PASSWORD)
            print(f"created initial Uptime Kuma user {KUMA_USERNAME!r}")
        api.login(KUMA_USERNAME, KUMA_PASSWORD)

        parents: dict[str, int] = {}
        for group in GROUPS:
            parents[group["name"]] = upsert_monitor(api, group, parents)

        for monitor in ENDPOINT_MONITORS:
            upsert_monitor(api, monitor, parents)

        docker_host_id = ensure_docker_host(api)
        for container in BACKGROUND_CONTAINERS:
            upsert_monitor(
                api,
                {
                    "name": f"Container / {container}",
                    "type": MonitorType.DOCKER,
                    "docker_container": container,
                    "docker_host": docker_host_id,
                    "parent_name": "Background services",
                },
                parents,
            )
    finally:
        api.disconnect()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"provisioning failed ({type(error).__name__}): {error!r}",
            file=sys.stderr,
        )
        traceback.print_exc()
        raise SystemExit(1) from error
