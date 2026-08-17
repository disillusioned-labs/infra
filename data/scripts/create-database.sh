#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="data-postgres"
POSTGRES_USER="postgres"
POSTGRES_DB="postgres"

SERVICE_NAME="${1:-}"
DB_PASSWORD="${2:-}"

if [[ -z "$SERVICE_NAME" || -z "$DB_PASSWORD" ]]; then
  echo "Usage: $0 <service-name> <database-password>"
  echo
  echo "Example:"
  echo "  $0 identity devpassword"
  exit 1
fi

DB_NAME="$SERVICE_NAME"
DB_USER="${SERVICE_NAME}_app"

echo "Provisioning PostgreSQL..."
echo "  database : $DB_NAME"
echo "  user     : $DB_USER"

podman exec -i "$CONTAINER_NAME" \
  psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 \
    -v db_user="$DB_USER" \
    -v db_name="$DB_NAME" \
    -v db_password="$DB_PASSWORD" <<'SQL'

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
echo "  database : $DB_NAME"
echo "  user     : $DB_USER"
echo "  host     : $CONTAINER_NAME"
echo "  port     : 5432"