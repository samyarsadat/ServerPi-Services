> [!NOTE]
> These need to be added to each container that needs monitoring!

Generic Promtail config:
```yaml
clients:
    - url: http://loki:3100/loki/api/v1/push

scrape_configs:
    - job_name: JOBNAME
      static_configs:
          - targets:
              - localhost
            labels:
                job: JOBNAME_log
                __path__: /PATH/TO/LOGS/*.log
```

Add to docker-compose.yml services:
```yaml
# LOG AGENT FOR PUSHING LOGS TO LOKI
promtail:
    image: grafana/promtail
    container_name: minecraft-promtail
    hostname: minecraft-promtail
    restart: unless-stopped
    volumes:
        - ./minecraft_data/logs:/var/log/minecraft:ro
        - ./promtail-config.yml:/etc/promtail-config.yml
    command:
        - '-config.file=/etc/promtail-config.yml'
```