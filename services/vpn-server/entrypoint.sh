#!/bin/bash
# ServerPi Services - WireGuard Docker Entrypoint File
# Prepared by Samyar Sadat Akhavi, 2024. 

set -e
echo "-> entrypoint.sh"

# Start the WireGuard exporter service
echo "-> Starting WireGuard exporter service"
rc-status -a
rc-service wireguard_exporter start

# Execute other commands
exec "$@"