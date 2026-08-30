#!/usr/bin/env bash
set -eu

repo_root="$(git rev-parse --show-toplevel)"
dashboard_factory_path="$repo_root/monitoring/scripts/dashboard_factory.jq"
dashboard_dir="$repo_root/monitoring/dashboards"

declare -A dashboards=(
    [fleet]="fleet_overview.json"
    [hosts]="linux_hosts.json"
    [docker]="docker_services.json"
    [edge]="caddy_edge.json"
    [observability]="observability_stack.json"
    [wireguard]="wireguard.json"
    [authelia]="authelia.json"
    [mail]="mailserver.json"
    [wordpress]="wordpress.json"
)

for dashboard in "${!dashboards[@]}"; do
    jq -n --arg dashboard "$dashboard" -f "$dashboard_factory_path" > "$dashboard_dir/${dashboards[$dashboard]}"
done