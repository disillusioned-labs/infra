#!/usr/bin/env bash

set -u

echo "========================================"
echo " Observability Stack Health Check"
echo " $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "========================================"
echo

ok=0
fail=0

check_http() {
    local name="$1"
    local url="$2"

    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
        printf "[ OK ] %-12s %s\n" "$name" "$url"
        ((ok++))
    else
        printf "[FAIL] %-12s %s\n" "$name" "$url"
        ((fail++))
    fi
}

check_container() {
    local name="$1"

    if ! podman container exists "$name" 2>/dev/null; then
        printf "[FAIL] %-12s container not found\n" "$name"
        ((fail++))
        return
    fi

    local status
    local restart_count

    status=$(podman inspect "$name" \
        --format '{{.State.Status}}' 2>/dev/null)

    restart_count=$(podman inspect "$name" \
        --format '{{.RestartCount}}' 2>/dev/null)

    if [[ "$status" == "running" ]]; then
        printf "[ OK ] %-12s running (restarts: %s)\n" \
            "$name" "$restart_count"
    else
        printf "[FAIL] %-12s status=%s (restarts: %s)\n" \
            "$name" "$status" "$restart_count"
        ((fail++))
    fi
}

echo "=== HTTP Readiness ==="

check_http "Grafana" "http://127.0.0.1:3000/api/health"
check_http "Loki"    "http://127.0.0.1:3100/ready"
check_http "Tempo"   "http://127.0.0.1:3200/ready"
check_http "Mimir"   "http://127.0.0.1:9009/ready"
check_http "OTel"    "http://127.0.0.1:13133/"

echo
echo "=== Container Status ==="

check_container "observability-grafana"
check_container "observability-loki"
check_container "observability-tempo"
check_container "observability-mimir"
check_container "observability-otel-collector"
check_container "observability-postgres-exporter"
check_container "observability-redis-exporter"
check_container "observability-podman-exporter"
check_container "observability-node-exporter"
check_container "observability-kafka-exporter"

echo
echo "========================================"
printf " Result: %s OK / %s FAIL\n" "$ok" "$fail"
echo "========================================"

if (( fail > 0 )); then
    exit 1
fi

exit 0
