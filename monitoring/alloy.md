> [!NOTE]
> These need to be added to each container that needs monitoring!

Generic Alloy config:
```alloy
local.file_match "service_logs" {
    path_targets = [{
        "__path__" = "/var/log/service/*.log",
        "job"      = "service_log",
        "host"     = "server-pi",
    }]
}

loki.source.file "service_logs" {
    targets       = local.file_match.service_logs.targets
    forward_to    = [loki.write.local.receiver]
    tail_from_end = true
}

loki.write "local" {
    endpoint {
        url = "http://loki:3100/loki/api/v1/push"
    }
}
```

Add to docker-compose.yml services:
```yaml
# LOG AGENT FOR PUSHING LOGS TO LOKI
alloy:
    image: grafana/alloy:v1.18.1
    container_name: service-alloy
    hostname: service-alloy
    restart: unless-stopped
    depends_on:
        service:
            condition: service_started
    volumes:
        - ./alloy-config.alloy:/etc/alloy/config.alloy:ro
        - ./caddy_data/logs:/var/log/service:ro
        - ./alloy_data:/var/lib/alloy/data
    command:
        - run
        - --server.http.listen-addr=0.0.0.0:12345
        - --storage.path=/var/lib/alloy/data
        - --disable-reporting
        - /etc/alloy/config.alloy
```