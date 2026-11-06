#!/bin/bash
# Warning: generated with AI assistance!
set -euo pipefail

# fix log file permissions for the exporter
touch /var/log/mail/mail.log
chgrp adm /var/log/mail/mail.log
chmod 0640 /var/log/mail/mail.log

SPLIT_DOMAINS=("gigawhat.net")
ACCOUNTS_FILE="/tmp/docker-mailserver/postfix-accounts.cf"
TRANSPORT_SRC="/etc/postfix/dms-split-transport"
LMTP_TRANSPORT="lmtp:unix:/var/run/dovecot/lmtp"
RELAY_NEXTHOP="[${RELAY_HOST:?RELAY_HOST not set}]:${RELAY_PORT:-25}"

: > "${TRANSPORT_SRC}"

for domain in "${SPLIT_DOMAINS[@]}"; do
    if [[ -f "${ACCOUNTS_FILE}" ]]; then
        awk -F'|' -v d="@${domain}" -v lmtp="${LMTP_TRANSPORT}" '
            {
                address = tolower($1)
                suffix = tolower(d)

                if (length(address) >= length(suffix) &&
                    substr(address, length(address) - length(suffix) + 1) == suffix) {
                    print address "\t" lmtp
                }
            }
        ' "${ACCOUNTS_FILE}" >> "${TRANSPORT_SRC}"
    fi
    printf '%s\trelay:%s\n' "${domain}" "${RELAY_NEXTHOP}" >> "${TRANSPORT_SRC}"
done

OUR_MAP="texthash:${TRANSPORT_SRC}"
CURRENT="$(postconf -h transport_maps 2>/dev/null || true)"
case ",${CURRENT// /}," in
    *",${OUR_MAP},"*) ;;
    *) postconf -e "transport_maps = ${OUR_MAP}${CURRENT:+, ${CURRENT}}" ;;
esac

postfix reload 2>/dev/null || true

echo "[user-patches] split-domain transport map regenerated:"
sed 's/^/[user-patches]   /' "${TRANSPORT_SRC}"