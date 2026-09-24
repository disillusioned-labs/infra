#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
secrets_dir="${script_dir}/../secrets"
postgres_secret="${secrets_dir}/postgres-exporter-password"
redis_secret="${secrets_dir}/redis-exporter-password"

if [[ -e "$postgres_secret" || -e "$redis_secret" ]]; then
  echo "Monitoring secret files already exist; refusing to overwrite them." >&2
  exit 1
fi

command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to generate monitoring secrets." >&2
  exit 1
}

umask 077
mkdir -p "$secrets_dir"
chmod 700 "$secrets_dir"
openssl rand -hex 32 | tr -d '\n' > "$postgres_secret"
openssl rand -hex 32 | tr -d '\n' > "$redis_secret"
# Compose file-backed secrets preserve the source file's readability in some
# providers. Keep the directory private on the host, and let the non-root
# exporter UIDs read only the files explicitly mounted into their containers.
chmod 644 "$postgres_secret" "$redis_secret"

echo "Created local monitoring secrets in ${secrets_dir}."
echo "Keep these files private; they are excluded from Git."
