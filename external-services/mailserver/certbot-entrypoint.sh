#!/bin/sh
set -eu

credentials=/tmp/cf.ini
umask 077
printf 'dns_cloudflare_api_token = %s\n' "${CF_DNS_API_TOKEN}" > "$credentials"

cleanup() {
    rm -f "$credentials"
}
trap 'cleanup; exit 0' INT TERM
trap cleanup EXIT

while :; do
    if certbot certonly --non-interactive --agree-tos --keep-until-expiring --reuse-key \
        --email "${CERTBOT_EMAIL}" \
        --dns-cloudflare --dns-cloudflare-credentials "$credentials" \
        --dns-cloudflare-propagation-seconds 30 \
        -d "${CERT_DOMAIN}"; then
        sleep 43200
    else
        echo "Certificate issuance failed; retrying in five minutes." >&2
        sleep 300
    fi
done
