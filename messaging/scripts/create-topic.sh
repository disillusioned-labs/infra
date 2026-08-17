#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="messaging-kafka"

TOPIC_NAME="${1:-}"
PARTITIONS="${2:-3}"

if [[ -z "$TOPIC_NAME" ]]; then
  echo "Usage: $0 <topic-name> [partitions]"
  echo
  echo "Example:"
  echo "  $0 identity.user.created"
  echo "  $0 identity.user.created 6"
  exit 1
fi

echo "Creating Kafka topic..."
echo "  topic      : $TOPIC_NAME"
echo "  partitions : $PARTITIONS"

docker exec "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --if-not-exists \
  --topic "$TOPIC_NAME" \
  --partitions "$PARTITIONS" \
  --replication-factor 1

echo
echo "Done."
echo "  topic      : $TOPIC_NAME"
echo "  partitions : $PARTITIONS"