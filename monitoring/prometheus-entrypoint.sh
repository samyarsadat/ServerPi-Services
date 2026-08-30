#!/bin/sh
set -eu

# I don't really like this solution, but from what I can tell,
# it's either this or having to add an option to the secrets manager
# to allow for creating raw secrets files that don't require root to be read.
# Or running Prometheus as root inside the container.
umask 077
printf '%s' "$SLYMETRICS_BEARER_TOKEN" > /tmp/wordpress_slymetrics_bearer_token
unset SLYMETRICS_BEARER_TOKEN

exec /bin/prometheus "$@"