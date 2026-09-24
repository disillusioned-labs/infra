# PostgreSQL and Redis monitoring

This stack scrapes `postgres_exporter` and `redis_exporter` every 30 seconds
through the OpenTelemetry Collector and sends the metrics to Mimir. Exporter
ports are not published on the host. The `observability-metrics` bridge is
internal; application containers stay on the separate `data` network.

## One-time setup

Ensure `data/.env` and `observability/.env` have been created from their example
files. Keep those files local and ignored by Git. Copy `POSTGRES_USER`,
`POSTGRES_PASSWORD`, and `POSTGRES_DB` from `data/.env` into `observability/.env`
so the exporter can connect with the existing database credentials. Then run
from this directory on the Podman host:

```sh
podman compose up -d postgres redis
```

Then start or update the observability stack:

```sh
cd ../observability
podman compose up -d
```

The Redis update restarts Redis once, so expect a brief cache interruption and
ensure clients retry connections. It preserves the existing data volume and
unauthenticated access. The Postgres exporter uses the configured `POSTGRES_USER`
and `POSTGRES_PASSWORD`; these are the database administrator credentials.

## Scope and security note

The dashboard distinguishes exporter scrape health from database reachability
and shows connection/resource pressure, transaction or command rates, cache
efficiency, deadlocks, and Redis evictions. Uptime Kuma's existing TCP checks
remain useful for basic reachability; they do not replace these database metrics.

The Redis default user remains unauthenticated to preserve compatibility with
current applications. Production Redis authentication and network exposure
should be addressed as a separate, coordinated app-credential migration.
