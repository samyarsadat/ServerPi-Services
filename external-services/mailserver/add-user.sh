#!/bin/bash
set -euo pipefail
CONTAINER_NAME="mailserver"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <email> <password>"
    exit 1
fi

docker exec "$CONTAINER_NAME" setup email add "$1" "$2"
docker exec "$CONTAINER_NAME" /tmp/docker-mailserver/user-patches.sh