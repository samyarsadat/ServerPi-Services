#!/bin/bash
# Returns regex patterns for Cloudflare's IP lists

ipv4_url="https://www.cloudflare.com/ips-v4"
ipv6_url="https://www.cloudflare.com/ips-v6"

ipv4_ips=($(curl -s $ipv4_url))
ipv6_ips=($(curl -s $ipv6_url))

create_regex() {
    local ips=("$@")
    local regex=""

    for ip in "${ips[@]}"; do
        regex+=$(echo $ip | sed 's/\./\\./g')
        regex+="|"
    done

    echo "${regex%|}"
}

ipv4_regex=$(create_regex "${ipv4_ips[@]}")
ipv6_regex=$(create_regex "${ipv6_ips[@]}")

echo "IPv4 regex: $ipv4_regex"
echo "IPv6 regex: $ipv6_regex"