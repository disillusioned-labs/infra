# PostgreSQL and Redis monitoring

This stack scrapes `postgres_exporter` and `redis_exporter` every 30 seconds
through the OpenTelemetry Collector and sends the metrics to Mimir. Exporter
ports are not published on the host. The `observability-metrics` bridge is
internal; application containers stay on the separate `data` network.

## One-time setup

Ensure `data/.env` and `observability/.env` have been created from their example
files and contain the host's existing, strong application credentials. Keep
those files local and ignored by Git. Then run from this directory on the
Podman host:

```sh
bash scripts/generate-monitoring-secrets.sh
podman compose up -d postgres redis
bash scripts/create-postgres-exporter-role.sh
```

Then start or update the observability stack:

```sh
cd ../observability
podman compose up -d
```

The secret files are local-only and ignored by Git. The containing directory is
mode `0700`; the files are readable by container UIDs because Compose file-backed
secrets may preserve source-file permissions. Back them up securely; if they are
lost, generate replacements and rerun the Postgres role provisioning script.
Keep the secret files available to Compose on every restart.

The first Redis update restarts Redis once, so expect a brief cache interruption
and ensure clients retry connections. It preserves the existing data volume and
the current default user's unauthenticated behavior, while adding a separate ACL
user for the exporter. PostgreSQL gets a dedicated `postgres_exporter` login
with the built-in `pg_monitor` role and a three-connection limit. After restoring
a Postgres volume, rerun the role provisioning script before relying on its
dashboard.

## Scope and security note

The dashboard distinguishes exporter scrape health from database reachability
and shows connection/resource pressure, transaction or command rates, cache
efficiency, deadlocks, and Redis evictions. Uptime Kuma's existing TCP checks
remain useful for basic reachability; they do not replace these database metrics.

This only hardens the monitoring path. Redis's existing default user remains
open to preserve compatibility with current applications; production Redis
authentication and network exposure should be addressed as a separate,
coordinated app-credential migration.
