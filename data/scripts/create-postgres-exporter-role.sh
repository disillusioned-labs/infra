#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
secret_file="${script_dir}/../secrets/postgres-exporter-password"
container_name="${POSTGRES_CONTAINER_NAME:-data-postgres}"
postgres_user="${POSTGRES_USER:-postgres}"
postgres_db="${POSTGRES_DB:-postgres}"
container_runtime="${CONTAINER_RUNTIME:-podman}"

if [[ ! -r "$secret_file" ]]; then
  echo "Missing ${secret_file}; run generate-monitoring-secrets.sh first." >&2
  exit 1
fi

password="$(tr -d '\r\n' < "$secret_file")"
if [[ ! "$password" =~ ^[a-f0-9]{64}$ ]]; then
  echo "The Postgres exporter password must be a 64-character lowercase hex secret." >&2
  exit 1
fi

# Send the secret over stdin instead of placing it in the podman/psql arguments.
{
  printf '\\set db_password %s\n' "$password"
  cat <<'SQL'
SELECT format(
  'CREATE ROLE postgres_exporter LOGIN PASSWORD %L CONNECTION LIMIT 3',
  :'db_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = 'postgres_exporter'
)
\gexec

ALTER ROLE postgres_exporter
  LOGIN PASSWORD :'db_password'
  CONNECTION LIMIT 3;

GRANT pg_monitor TO postgres_exporter;
GRANT CONNECT ON DATABASE postgres TO postgres_exporter;
SQL
} | "$container_runtime" exec -i "$container_name" \
  psql -X -U "$postgres_user" -d "$postgres_db" -v ON_ERROR_STOP=1

echo "Provisioned the least-privilege postgres_exporter role on ${container_name}."
