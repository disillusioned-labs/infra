#!/usr/bin/env bash

set -euo pipefail

container_name="data-postgres"
postgres_user="postgres"
postgres_db="postgres"

service_name="${1:-}"
db_password="${2:-}"

if [[ -z "$service_name" || -z "$db_password" ]]; then
  echo "Usage: $0 <service-name> <database-password>"
  echo
  echo "Example:"
  echo "  $0 identity devpassword"
  exit 1
fi

db_name="$service_name"
db_user="${service_name}_app"

echo "Provisioning PostgreSQL..."
echo "  database : $db_name"
echo "  user     : $db_user"

podman exec -i "$container_name" \
  psql \
    -U "$postgres_user" \
    -d "$postgres_db" \
    -v ON_ERROR_STOP=1 \
    -v db_user="$db_user" \
    -v db_name="$db_name" \
    -v db_password="$db_password" <<'SQL'

SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'db_user',
  :'db_password'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = :'db_user'
)
\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  :'db_name',
  :'db_user'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_database
  WHERE datname = :'db_name'
)
\gexec

SQL

echo
echo "Database provisioning complete."
echo "  database : $db_name"
echo "  user     : $db_user"
echo "  host     : $container_name"
echo "  port     : 5432"
