#!/bin/sh
# ServerPi Services - certbot renewal loop for docker-mailserver's TLS cert.
# Obtains/renews mail.ssa-selfhosted.com via Cloudflare DNS-01.

umask 077
echo "dns_cloudflare_api_token = ${CF_DNS_API_TOKEN}" > /tmp/cf.ini

trap exit TERM
while :; do
    certbot certonly --non-interactive --agree-tos --keep-until-expiring --reuse-key \
        --email "${CERTBOT_EMAIL}" \
        --dns-cloudflare --dns-cloudflare-credentials /tmp/cf.ini \
        --dns-cloudflare-propagation-seconds 30 \
        -d "${CERT_DOMAIN}"
    sleep 43200   # re-check every 12h
done
