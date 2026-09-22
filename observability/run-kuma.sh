#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v podman >/dev/null 2>&1; then
    echo "Error: podman is not installed or is not in PATH." >&2
    exit 1
fi

if [[ ! -f .env ]]; then
    echo "Error: observability/.env does not exist." >&2
    echo "Create it with: cp .env.example .env" >&2
    exit 1
fi

if ! grep -Eq '^[[:space:]]*KUMA_PASSWORD=.+$' .env; then
    echo "Error: set KUMA_PASSWORD in observability/.env." >&2
    exit 1
fi

for network in data messaging; do
    if ! podman network exists "$network"; then
        echo "Error: required Podman network '$network' does not exist." >&2
        exit 1
    fi
done

echo "Building the Uptime Kuma provisioner..."
podman compose --profile ops build --pull=always kuma-provisioner

echo "Pulling the socket proxy from Docker Hub before stopping Kuma..."
podman compose pull podman-socket-proxy

echo "Removing only the previous Uptime Kuma containers..."
# Remove dependants before their dependencies.
for container in \
    observability-kuma-provisioner \
    observability-uptime-kuma \
    observability-socket-proxy \
    observability-podman-socket-proxy; do
    podman rm --force --ignore "$container"
done

echo "Starting Uptime Kuma and its socket proxy..."
podman compose up -d uptime-kuma

echo "Applying the repository-managed monitor configuration..."
podman compose --profile ops run --rm kuma-provisioner

echo "Uptime Kuma is ready. Current status:"
podman compose ps uptime-kuma podman-socket-proxy
