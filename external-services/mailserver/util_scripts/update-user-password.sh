#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <email>" >&2
    exit 1
fi

docker exec -it mailserver setup email update "$1"