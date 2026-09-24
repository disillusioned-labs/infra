#!/bin/sh

set -eu

secret_file=/run/secrets/redis_exporter_password
password="$(tr -d '\r\n' < "$secret_file")"

case "$password" in
  ''|*[!a-f0-9]*)
    echo "redis exporter password must be a 64-character lowercase hex secret" >&2
    exit 1
    ;;
esac

if [ "${#password}" -ne 64 ]; then
  echo "redis exporter password must be a 64-character lowercase hex secret" >&2
  exit 1
fi

password_hash="$(printf '%s' "$password" | sha256sum | cut -d ' ' -f 1)"
acl_file=/tmp/redis-users.acl
umask 077

cat > "$acl_file" <<EOF
user default on nopass ~* &* +@all
user redis_exporter on #${password_hash} ~* &* +@connection +memory -readonly +strlen +config|get +xinfo +pfcount -quit +zcard +type +xlen -readwrite -command +client -wait +scard +llen +hlen +arcount +get +eval_ro +slowlog +cluster|info +cluster|slots +cluster|nodes -hello -echo +info +latency +scan -reset -auth -asking
EOF
chmod 0444 "$acl_file"

exec /usr/local/bin/docker-entrypoint.sh redis-server --aclfile "$acl_file"
