#!/usr/bin/env bash

set -euo pipefail

container_name="messaging-kafka"

topic_name="${1:-}"
partitions="${2:-3}"

if [[ -z "$topic_name" ]]; then
  echo "Usage: $0 <topic-name> [partitions]"
  echo
  echo "Example:"
  echo "  $0 identity.user.created"
  echo "  $0 identity.user.created 6"
  exit 1
fi

echo "Creating Kafka topic..."
echo "  topic      : $topic_name"
echo "  partitions : $partitions"

podman exec "$container_name" \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --if-not-exists \
  --topic "$topic_name" \
  --partitions "$partitions" \
  --replication-factor 1

echo
echo "Done."
echo "  topic      : $topic_name"
echo "  partitions : $partitions"
