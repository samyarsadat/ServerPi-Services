# ServerPi Services - WireGuard VPN Server Docker Image
# Prepared by Samyar Sadat Akhavi, 2024. 

FROM golang:1.22-bookworm AS builder

# Build and install wireguard_exporter
RUN mkdir -p /tmp/wireguard_exporter && cd /tmp/wireguard_exporter \
    && git clone https://github.com/mdlayher/wireguard_exporter . \
    && cd ./cmd/wireguard_exporter/ \
    && go build -tags netgo . \
    && mv wireguard_exporter /bin/wireguard_exporter \
    && cd / && rm -rf /tmp/wireguard_exporter

# WireGuard VPN Server Docker Image
FROM ghcr.io/wg-easy/wg-easy

# Install OpenRC
RUN apk add --no-cache openrc

# Bring in wireguard_exporter
COPY --from=builder /bin/wireguard_exporter /bin/wireguard_exporter
COPY exporter_name_mappings.toml /etc/wireguard_exporter/peers.toml
COPY wireguard_exporter.in /etc/init.d/wireguard_exporter

# OpenRC fix
VOLUME /sys/fs/cgroup
RUN mkdir -p /run/openrc \
    && touch /run/openrc/softlevel

# Add exporter service to OpenRC
RUN chmod +x /etc/init.d/wireguard_exporter \
    && rc-status -a && rc-update add wireguard_exporter default

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Run WireGuard-Easy
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]