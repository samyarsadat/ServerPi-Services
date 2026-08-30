def prometheus: {type: "prometheus", uid: "yFPhw6sIz"};
def loki: {type: "loki", uid: "loki"};
def refids: ["A", "B", "C", "D", "E", "F", "G", "H"];
def grid($x; $y; $w; $h): {x: $x, y: $y, w: $w, h: $h};
def thresholds: {mode: "absolute", steps: [{color: "green", value: null}, {color: "orange", value: 70}, {color: "red", value: 90}]};
def bad_thresholds: {mode: "absolute", steps: [{color: "green", value: null}, {color: "red", value: 1}]};
def series_defaults($unit): {
  color: {mode: "palette-classic"},
  custom: {
    axisBorderShow: false, axisCenteredZero: false, axisColorMode: "text", axisPlacement: "auto",
    drawStyle: "line", fillOpacity: 14, gradientMode: "opacity", lineInterpolation: "smooth",
    lineWidth: 2, pointSize: 4, showPoints: "never", spanNulls: false,
    stacking: {group: "A", mode: "none"}, thresholdsStyle: {mode: "off"}
  },
  mappings: [], thresholds: thresholds, unit: $unit
};
def prom_target($expr; $legend): {
  datasource: prometheus, editorMode: "code", expr: $expr, instant: false,
  legendFormat: $legend, range: true, refId: "A"
};
def loki_target($expr; $legend): {
  datasource: loki, editorMode: "code", expr: $expr,
  legendFormat: $legend, queryType: "range", refId: "A"
};
def row($id; $title; $y): {
  collapsed: false, gridPos: grid(0; $y; 24; 1), id: $id, panels: [], title: $title, type: "row"
};
def stat($id; $title; $expr; $unit; $x; $y; $w): {
  datasource: prometheus,
  fieldConfig: {defaults: {color: {mode: "thresholds"}, mappings: [], thresholds: thresholds, unit: $unit}, overrides: []},
  gridPos: grid($x; $y; $w; 4), id: $id,
  options: {colorMode: "background", graphMode: "area", justifyMode: "auto", orientation: "auto",
    reduceOptions: {calcs: ["lastNotNull"], fields: "", values: false}, textMode: "auto", wideLayout: true},
  targets: [prom_target($expr; "")], title: $title, type: "stat"
};
def stat_bad($id; $title; $expr; $unit; $x; $y; $w):
  stat($id; $title; $expr; $unit; $x; $y; $w)
  | .fieldConfig.defaults.thresholds = bad_thresholds;
def timeseries($id; $title; $targets; $unit; $x; $y; $w; $h): {
  datasource: prometheus, fieldConfig: {defaults: series_defaults($unit), overrides: []},
  gridPos: grid($x; $y; $w; $h), id: $id,
  options: {legend: {calcs: ["lastNotNull", "mean", "max"], displayMode: "table", placement: "bottom", showLegend: true},
    tooltip: {hideZeros: false, mode: "multi", sort: "desc"}},
  targets: $targets, title: $title, type: "timeseries"
};
def loki_series($id; $title; $targets; $unit; $x; $y; $w; $h):
  timeseries($id; $title; $targets; $unit; $x; $y; $w; $h) | .datasource = loki;
def pie($id; $title; $target; $x; $y; $w; $h): {
  datasource: prometheus, fieldConfig: {defaults: {color: {mode: "palette-classic"}, mappings: [], unit: "short"}, overrides: []},
  gridPos: grid($x; $y; $w; $h), id: $id,
  options: {displayLabels: ["name", "percent"], legend: {displayMode: "table", placement: "right", showLegend: true, values: ["percent", "value"]},
    pieType: "donut", reduceOptions: {calcs: ["lastNotNull"], fields: "", values: false}, tooltip: {mode: "single", sort: "none"}},
  targets: [$target], title: $title, type: "piechart"
};
def table($id; $title; $targets; $unit; $x; $y; $w; $h): {
  datasource: prometheus, fieldConfig: {defaults: {color: {mode: "thresholds"}, mappings: [], thresholds: thresholds, unit: $unit}, overrides: []},
  gridPos: grid($x; $y; $w; $h), id: $id,
  options: {cellHeight: "sm", footer: {countRows: false, fields: "", reducer: ["sum"], show: false}, showHeader: true, sortBy: [{desc: true, displayName: "Value"}]},
  targets: $targets, title: $title, transformations: [{id: "labelsToFields", options: {mode: "columns"}}], type: "table"
};
def logs($id; $title; $expr; $x; $y; $w; $h): {
  datasource: loki, gridPos: grid($x; $y; $w; $h), id: $id,
  options: {dedupStrategy: "none", enableInfiniteScrolling: false, enableLogDetails: true, prettifyLogMessage: false,
    showCommonLabels: false, showLabels: false, showTime: true, sortOrder: "Descending", wrapLogMessage: true},
  targets: [loki_target($expr; "")], title: $title, type: "logs"
};
def host_var($query): {
  name: "host", label: "Host", type: "query", datasource: prometheus,
  definition: $query, query: {query: $query, refId: "StandardVariableQuery"},
  current: {selected: true, text: ["All"], value: ["$__all"]}, includeAll: true, multi: true,
  allValue: ".*", refresh: 1, sort: 1, hide: 0, skipUrlSync: false
};
def query_var($name; $label; $query): {
  name: $name, label: $label, type: "query", datasource: prometheus,
  definition: $query, query: {query: $query, refId: "StandardVariableQuery"},
  current: {selected: true, text: ["All"], value: ["$__all"]}, includeAll: true, multi: true,
  allValue: ".*", refresh: 1, sort: 1, hide: 0, skipUrlSync: false
};
def dashboard($uid; $title; $description; $tags; $variables; $panels): {
  annotations: {list: [{builtIn: 1, datasource: {type: "grafana", uid: "-- Grafana --"}, enable: true, hide: true,
    iconColor: "rgba(0, 211, 255, 1)", name: "Annotations & Alerts", type: "dashboard"}]},
  description: $description, editable: true, fiscalYearStartMonth: 0, graphTooltip: 1, id: null, links: [], liveNow: false,
  panels: ($panels | map(if has("targets") then .targets |= (to_entries | map(.value + {refId: refids[.key]})) else . end)),
  refresh: "30s", schemaVersion: 42, tags: (["serverpi", "provisioned"] + $tags),
  templating: {list: $variables}, time: {from: "now-6h", to: "now"}, timepicker: {}, timezone: "browser",
  title: $title, uid: $uid, version: 1, weekStart: "monday"
};

def fleet:
  dashboard("serverpi-fleet-overview"; "ServerPi / Fleet Overview";
    "Health for both hosts, Docker workloads, and Prometheus targets.";
    ["overview", "docker", "node-exporter"];
    [host_var("label_values(node_uname_info, host)")];
    [
      row(100; "Fleet health"; 0),
      stat(1; "Healthy targets"; "sum(up{host=~\"$host\"})"; "short"; 0; 1; 4),
      stat_bad(2; "Targets down"; "sum(up{host=~\"$host\"} == 0)"; "short"; 4; 1; 4),
      stat(3; "Hosts reporting"; "count(count by (host) (node_uname_info{host=~\"$host\"}))"; "short"; 8; 1; 4),
      stat(4; "Containers reporting"; "count(count by (host, name) (container_last_seen{host=~\"$host\",image!=\"\"}))"; "short"; 12; 1; 4),
      stat(5; "Edge requests / second"; "sum(rate(caddy_http_requests_total{host=~\"$host\"}[$__rate_interval]))"; "reqps"; 16; 1; 4),
      stat_bad(6; "Authentication failures"; "sum(increase(authelia_authn{success=\"false\"}[$__range]))"; "short"; 20; 1; 4),
      row(101; "Host saturation"; 5),
      timeseries(7; "CPU utilization"; [prom_target("100 * (1 - avg by (host) (rate(node_cpu_seconds_total{host=~\"$host\",mode=\"idle\"}[$__rate_interval])))"; "{{host}}")] ; "percent"; 0; 6; 12; 8),
      timeseries(8; "Memory utilization"; [prom_target("100 * (1 - node_memory_MemAvailable_bytes{host=~\"$host\"} / node_memory_MemTotal_bytes{host=~\"$host\"})"; "{{host}}")] ; "percent"; 12; 6; 12; 8),
      timeseries(9; "Root filesystem utilization"; [prom_target("100 * (1 - node_filesystem_avail_bytes{host=~\"$host\",mountpoint=\"/\",fstype!=\"\"} / node_filesystem_size_bytes{host=~\"$host\",mountpoint=\"/\",fstype!=\"\"})"; "{{host}}")] ; "percent"; 0; 14; 12; 8),
      timeseries(10; "System load"; [prom_target("node_load1{host=~\"$host\"}"; "{{host}} load 1m"), prom_target("node_load5{host=~\"$host\"}"; "{{host}} load 5m")] ; "short"; 12; 14; 12; 8),
      row(102; "Workloads and targets"; 22),
      table(11; "Top containers by memory"; [prom_target("topk(15, sum by (host, name) (container_memory_working_set_bytes{host=~\"$host\",image!=\"\"}))"; "{{host}} / {{name}}") | .instant=true | .range=false] ; "bytes"; 0; 23; 12; 9),
      table(12; "Prometheus target state"; [prom_target("up{host=~\"$host\"}"; "{{host}} / {{job}} / {{instance}}") | .instant=true | .range=false] ; "short"; 12; 23; 12; 9)
    ]);

def hosts:
  dashboard("serverpi-linux-hosts"; "ServerPi / Linux Hosts";
    "Linux host dashboard; based on Grafana dashboard 1860.";
    ["linux", "node-exporter", "raspberry-pi"];
    [host_var("label_values(node_uname_info, host)")];
    [
      row(100; "Host summary"; 0),
      stat(1; "Uptime"; "max(time() - node_boot_time_seconds{host=~\"$host\"})"; "s"; 0; 1; 4),
      stat(2; "CPU cores"; "count(count by (host, cpu) (node_cpu_seconds_total{host=~\"$host\",mode=\"idle\"}))"; "short"; 4; 1; 4),
      stat(3; "Memory available"; "sum(node_memory_MemAvailable_bytes{host=~\"$host\"})"; "bytes"; 8; 1; 4),
      stat(4; "Root disk free"; "sum(node_filesystem_avail_bytes{host=~\"$host\",mountpoint=\"/\",fstype!=\"\"})"; "bytes"; 12; 1; 4),
      stat(5; "Load (1 minute)"; "sum(node_load1{host=~\"$host\"})"; "short"; 16; 1; 4),
      stat(6; "Peak temperature"; "max(node_hwmon_temp_celsius{host=~\"$host\"})"; "celsius"; 20; 1; 4),
      row(101; "CPU and memory"; 5),
      timeseries(7; "CPU utilization"; [prom_target("100 * (1 - avg by (host) (rate(node_cpu_seconds_total{host=~\"$host\",mode=\"idle\"}[$__rate_interval])))"; "{{host}}")] ; "percent"; 0; 6; 12; 8),
      timeseries(8; "CPU time by mode"; [prom_target("100 * avg by (host, mode) (rate(node_cpu_seconds_total{host=~\"$host\",mode!=\"idle\"}[$__rate_interval]))"; "{{host}} / {{mode}}")] ; "percent"; 12; 6; 12; 8),
      timeseries(9; "Memory composition"; [prom_target("node_memory_MemTotal_bytes{host=~\"$host\"} - node_memory_MemAvailable_bytes{host=~\"$host\"}"; "{{host}} used"), prom_target("node_memory_Cached_bytes{host=~\"$host\"}"; "{{host}} cache"), prom_target("node_memory_Buffers_bytes{host=~\"$host\"}"; "{{host}} buffers")] ; "bytes"; 0; 14; 12; 8),
      timeseries(10; "Load averages"; [prom_target("node_load1{host=~\"$host\"}"; "{{host}} 1m"), prom_target("node_load5{host=~\"$host\"}"; "{{host}} 5m"), prom_target("node_load15{host=~\"$host\"}"; "{{host}} 15m")] ; "short"; 12; 14; 12; 8),
      row(102; "Storage and network"; 22),
      timeseries(11; "Filesystem utilization"; [prom_target("100 * (1 - node_filesystem_avail_bytes{host=~\"$host\",fstype!~\"tmpfs|overlay|squashfs\"} / node_filesystem_size_bytes{host=~\"$host\",fstype!~\"tmpfs|overlay|squashfs\"})"; "{{host}} / {{mountpoint}}")] ; "percent"; 0; 23; 12; 9),
      timeseries(12; "Physical disk throughput"; [prom_target("sum by (host, device) (rate(node_disk_read_bytes_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]))"; "{{host}} / {{device}} read"), prom_target("sum by (host, device) (rate(node_disk_written_bytes_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]))"; "{{host}} / {{device}} write")] ; "Bps"; 12; 23; 12; 9),
      timeseries(13; "Network throughput"; [prom_target("sum by (host, device) (rate(node_network_receive_bytes_total{host=~\"$host\",device!~\"lo|veth.*|br-.*|docker.*\"}[$__rate_interval]))"; "{{host}} / {{device}} receive"), prom_target("sum by (host, device) (rate(node_network_transmit_bytes_total{host=~\"$host\",device!~\"lo|veth.*|br-.*|docker.*\"}[$__rate_interval]))"; "{{host}} / {{device}} transmit")] ; "Bps"; 0; 32; 12; 9),
      timeseries(14; "Disk latency"; [prom_target("rate(node_disk_read_time_seconds_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]) / clamp_min(rate(node_disk_reads_completed_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]), 1e-9)"; "{{host}} / {{device}} read"), prom_target("rate(node_disk_write_time_seconds_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]) / clamp_min(rate(node_disk_writes_completed_total{host=~\"$host\",device=~\"mmcblk[0-9]+|nvme[0-9]+n[0-9]+|sd[a-z]+\"}[$__rate_interval]), 1e-9)"; "{{host}} / {{device}} write")] ; "s"; 12; 32; 12; 9),
      row(103; "Kernel pressure and thermals"; 41),
      timeseries(15; "Pressure stall time"; [prom_target("rate(node_pressure_cpu_waiting_seconds_total{host=~\"$host\"}[$__rate_interval]) * 100"; "{{host}} CPU"), prom_target("rate(node_pressure_memory_waiting_seconds_total{host=~\"$host\"}[$__rate_interval]) * 100"; "{{host}} memory"), prom_target("rate(node_pressure_io_waiting_seconds_total{host=~\"$host\"}[$__rate_interval]) * 100"; "{{host}} I/O")] ; "percent"; 0; 42; 12; 8),
      timeseries(16; "Hardware temperatures"; [prom_target("node_hwmon_temp_celsius{host=~\"$host\"}"; "{{host}} / {{chip}} / {{sensor}}")] ; "celsius"; 12; 42; 12; 8)
    ]);

def docker_services:
  dashboard("serverpi-docker-services"; "ServerPi / Docker Services";
    "Container resource and liveness dashboard based on community dashboard 15798.";
    ["docker", "cadvisor", "containers"];
    [host_var("label_values(container_last_seen{image!=\"\"}, host)"), query_var("container"; "Container"; "label_values(container_last_seen{host=~\"$host\",image!=\"\"}, name)")];
    [
      row(100; "Container summary"; 0),
      stat(1; "Containers reporting"; "count(count by (host, name) (container_last_seen{host=~\"$host\",name=~\"$container\",image!=\"\"}))"; "short"; 0; 1; 6),
      stat(2; "CPU consumed"; "sum(rate(container_cpu_usage_seconds_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval])) * 100"; "percent"; 6; 1; 6),
      stat(3; "Working-set memory"; "sum(container_memory_working_set_bytes{host=~\"$host\",name=~\"$container\",image!=\"\"})"; "bytes"; 12; 1; 6),
      stat_bad(4; "Stale metric series"; "sum((time() - container_last_seen{host=~\"$host\",name=~\"$container\",image!=\"\"}) > bool 90)"; "short"; 18; 1; 6),
      row(101; "Resource utilization"; 5),
      timeseries(5; "CPU by container"; [prom_target("sum by (host, name) (rate(container_cpu_usage_seconds_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval])) * 100"; "{{host}} / {{name}}")] ; "percent"; 0; 6; 12; 9),
      timeseries(6; "Working-set memory by container"; [prom_target("sum by (host, name) (container_memory_working_set_bytes{host=~\"$host\",name=~\"$container\",image!=\"\"})"; "{{host}} / {{name}}")] ; "bytes"; 12; 6; 12; 9),
      timeseries(7; "Network throughput"; [prom_target("sum by (host, name) (rate(container_network_receive_bytes_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval]))"; "{{host}} / {{name}} receive"), prom_target("sum by (host, name) (rate(container_network_transmit_bytes_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval]))"; "{{host}} / {{name}} transmit")] ; "Bps"; 0; 15; 12; 9),
      timeseries(8; "Filesystem I/O"; [prom_target("sum by (host, name) (rate(container_fs_reads_bytes_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval]))"; "{{host}} / {{name}} read"), prom_target("sum by (host, name) (rate(container_fs_writes_bytes_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[$__rate_interval]))"; "{{host}} / {{name}} write")] ; "Bps"; 12; 15; 12; 9),
      row(102; "Capacity and diagnosis"; 24),
      table(9; "Memory ranking"; [prom_target("topk(25, sum by (host, name, image) (container_memory_working_set_bytes{host=~\"$host\",name=~\"$container\",image!=\"\"}))"; "{{host}} / {{name}}") | .instant=true | .range=false] ; "bytes"; 0; 25; 12; 10),
      table(10; "CPU ranking"; [prom_target("topk(25, sum by (host, name, image) (rate(container_cpu_usage_seconds_total{host=~\"$host\",name=~\"$container\",image!=\"\"}[5m])) * 100)"; "{{host}} / {{name}}") | .instant=true | .range=false] ; "percent"; 12; 25; 12; 10),
      timeseries(11; "Processes and threads"; [prom_target("sum by (host, name) (container_processes{host=~\"$host\",name=~\"$container\",image!=\"\"})"; "{{host}} / {{name}}")] ; "short"; 0; 35; 12; 8),
      timeseries(12; "Metric freshness"; [prom_target("time() - max by (host, name) (container_last_seen{host=~\"$host\",name=~\"$container\",image!=\"\"})"; "{{host}} / {{name}}")] ; "s"; 12; 35; 12; 8)
    ]);

def edge:
  dashboard("serverpi-caddy-edge"; "ServerPi / Caddy Edge & Traffic";
    "Caddy performance and access analytics based on community dashboards 22806 and 25216.";
    ["caddy", "loki", "http", "security"];
    [host_var("label_values(caddy_http_requests_total, host)"), query_var("handler"; "Handler"; "label_values(caddy_http_requests_total{host=~\"$host\"}, handler)")];
    [
      row(100; "Edge summary"; 0),
      stat(1; "Requests / second"; "sum(rate(caddy_http_requests_total{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval]))"; "reqps"; 0; 1; 6),
      stat_bad(2; "HTTP error percent"; "100 * sum(rate(caddy_http_request_duration_seconds_count{host=~\"$host\",code=~\"4..|5..\"}[$__rate_interval])) / clamp_min(sum(rate(caddy_http_request_duration_seconds_count{host=~\"$host\"}[$__rate_interval])), 1e-9)"; "percent"; 6; 1; 6),
      stat(3; "p95 response latency"; "histogram_quantile(0.95, sum by (le) (rate(caddy_http_response_duration_seconds_bucket{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval])))"; "s"; 12; 1; 6),
      stat(4; "Response bandwidth"; "sum(rate(caddy_http_response_size_bytes_sum{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval]))"; "Bps"; 18; 1; 6),
      row(101; "HTTP performance"; 5),
      timeseries(5; "Request rate by status"; [prom_target("sum by (host, code) (rate(caddy_http_request_duration_seconds_count{host=~\"$host\"}[$__rate_interval]))"; "{{host}} / {{code}}")] ; "reqps"; 0; 6; 12; 8),
      timeseries(6; "Request rate by handler"; [prom_target("sum by (host, handler) (rate(caddy_http_requests_total{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval]))"; "{{host}} / {{handler}}")] ; "reqps"; 12; 6; 12; 8),
      timeseries(7; "Response latency percentiles"; [prom_target("histogram_quantile(0.50, sum by (host, le) (rate(caddy_http_response_duration_seconds_bucket{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval])))"; "{{host}} p50"), prom_target("histogram_quantile(0.95, sum by (host, le) (rate(caddy_http_response_duration_seconds_bucket{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval])))"; "{{host}} p95"), prom_target("histogram_quantile(0.99, sum by (host, le) (rate(caddy_http_response_duration_seconds_bucket{host=~\"$host\",handler=~\"$handler\"}[$__rate_interval])))"; "{{host}} p99")] ; "s"; 0; 14; 12; 8),
      timeseries(8; "Requests in flight"; [prom_target("sum by (host) (caddy_http_requests_in_flight{host=~\"$host\"})"; "{{host}}")] ; "short"; 12; 14; 12; 8),
      row(102; "Access-log analytics"; 22),
      loki_series(9; "Requests by virtual host"; [loki_target("sum by (request_host) (rate({job=\"caddy_access_log\",host=~\"$host\"} | json [$__interval]))"; "{{request_host}}")] ; "reqps"; 0; 23; 12; 8),
      loki_series(10; "Responses by status"; [loki_target("sum by (status) (rate({job=\"caddy_access_log\",host=~\"$host\"} | json [$__interval]))"; "HTTP {{status}}")] ; "reqps"; 12; 23; 12; 8),
      loki_series(11; "Requests by client country"; [loki_target("topk(12, sum by (geoip_country_name) (rate({job=\"caddy_access_log\",host=~\"$host\"} | geoip_country_name != \"\" [$__interval])))"; "{{geoip_country_name}}")] ; "reqps"; 0; 31; 12; 8),
      loki_series(12; "Top direct / non-Cloudflare remote IPs"; [loki_target("topk(15, sum by (request_remote_ip) (rate({job=\"caddy_access_log\",host=~\"$host\"} | json request_remote_ip=\"request.remote_ip\" | request_remote_asn != \"\" | request_remote_asn != \"13335\" [$__interval])))"; "{{request_remote_ip}}")] ; "reqps"; 12; 31; 12; 8),
      logs(13; "Recent structured access logs"; "{job=\"caddy_access_log\",host=~\"$host\"} | json"; 0; 39; 24; 12)
    ]);

def observability:
  dashboard("serverpi-observability-stack"; "ServerPi / Observability Stack";
    "Operational health for Prometheus, Grafana, Loki, Alloy, exporters, scrape targets, and the monitoring containers.";
    ["prometheus", "grafana", "loki", "alloy"];
    [host_var("label_values(up, host)")];
    [
      row(100; "Stack health"; 0),
      stat_bad(1; "Targets down"; "sum(up{host=~\"$host\"} == 0)"; "short"; 0; 1; 4),
      stat(2; "Prometheus active series"; "sum(prometheus_tsdb_head_series{host=~\"$host\"})"; "short"; 4; 1; 4),
      stat(3; "Samples ingested / second"; "sum(rate(prometheus_tsdb_head_samples_appended_total{host=~\"$host\"}[$__rate_interval]))"; "ops"; 8; 1; 4),
      stat(4; "Loki bytes received / second"; "sum(rate(loki_distributor_bytes_received_total{host=~\"$host\"}[$__rate_interval]))"; "Bps"; 12; 1; 4),
      stat(5; "Grafana requests / second"; "sum(rate(grafana_http_request_duration_seconds_count{host=~\"$host\"}[$__rate_interval]))"; "reqps"; 16; 1; 4),
      stat_bad(6; "Unhealthy Alloy components"; "sum(alloy_component_controller_running_components{host=~\"$host\",health_type!=\"healthy\"})"; "short"; 20; 1; 4),
      row(101; "Prometheus"; 5),
      timeseries(7; "Scrape duration"; [prom_target("scrape_duration_seconds{host=~\"$host\"}"; "{{host}} / {{job}}")] ; "s"; 0; 6; 12; 8),
      timeseries(8; "Samples appended"; [prom_target("rate(prometheus_tsdb_head_samples_appended_total{host=~\"$host\"}[$__rate_interval])"; "{{host}}")] ; "ops"; 12; 6; 12; 8),
      timeseries(9; "TSDB head series and chunks"; [prom_target("prometheus_tsdb_head_series{host=~\"$host\"}"; "{{host}} series"), prom_target("prometheus_tsdb_head_chunks{host=~\"$host\"}"; "{{host}} chunks")] ; "short"; 0; 14; 12; 8),
      timeseries(10; "Prometheus HTTP requests"; [prom_target("sum by (host, code, handler) (rate(prometheus_http_requests_total{host=~\"$host\"}[$__rate_interval]))"; "{{host}} / {{code}} / {{handler}}")] ; "reqps"; 12; 14; 12; 8),
      row(102; "Grafana, Loki, and Alloy"; 22),
      timeseries(11; "Grafana HTTP requests"; [prom_target("sum by (host, status_code) (rate(grafana_http_request_duration_seconds_count{host=~\"$host\"}[$__rate_interval]))"; "{{host}} / {{status_code}}")] ; "reqps"; 0; 23; 8; 8),
      timeseries(12; "Loki request rate"; [prom_target("sum by (host, status_code, route) (rate(loki_request_duration_seconds_count{host=~\"$host\"}[$__rate_interval]))"; "{{host}} / {{status_code}} / {{route}}")] ; "reqps"; 8; 23; 8; 8),
      timeseries(13; "Alloy component health"; [prom_target("sum by (host, health_type) (alloy_component_controller_running_components{host=~\"$host\"})"; "{{host}} / {{health_type}}")] ; "short"; 16; 23; 8; 8),
      timeseries(14; "Monitoring container memory"; [prom_target("sum by (host, name) (container_memory_working_set_bytes{host=~\"$host\",container_label_org_label_schema_group=\"monitoring\"})"; "{{host}} / {{name}}")] ; "bytes"; 0; 31; 12; 8),
      timeseries(15; "Monitoring container CPU"; [prom_target("sum by (host, name) (rate(container_cpu_usage_seconds_total{host=~\"$host\",container_label_org_label_schema_group=\"monitoring\"}[$__rate_interval])) * 100"; "{{host}} / {{name}}")] ; "percent"; 12; 31; 12; 8),
      row(103; "Targets"; 39),
      table(16; "Current scrape target state"; [prom_target("up{host=~\"$host\"}"; "{{host}} / {{job}} / {{instance}}") | .instant=true | .range=false] ; "short"; 0; 40; 24; 10)
    ]);

def wireguard:
  dashboard("serverpi-wireguard"; "ServerPi / WireGuard";
    "wg-easy peer health and traffic dashboard, based on community dashboard 21733.";
    ["wireguard", "wg-easy", "vpn"];
    [query_var("peer"; "Peer"; "label_values(wireguard_latest_handshake_seconds, name)")];
    [
      row(100; "VPN summary"; 0),
      stat(1; "Configured peers"; "wireguard_configured_peers"; "short"; 0; 1; 6),
      stat(2; "Enabled peers"; "wireguard_enabled_peers"; "short"; 6; 1; 6),
      stat(3; "Connected peers"; "wireguard_connected_peers"; "short"; 12; 1; 6),
      stat_bad(4; "Disconnected enabled peers"; "clamp_min(wireguard_enabled_peers - wireguard_connected_peers, 0)"; "short"; 18; 1; 6),
      row(101; "Peer state"; 5),
      timeseries(5; "Handshake age by peer"; [prom_target("wireguard_latest_handshake_seconds{name=~\"$peer\"}"; "{{name}} / {{interface}}")] ; "s"; 0; 6; 12; 9),
      timeseries(6; "Peer traffic rate"; [prom_target("sum by (interface, name) (rate(wireguard_sent_bytes{name=~\"$peer\"}[$__rate_interval]))"; "{{name}} sent"), prom_target("sum by (interface, name) (rate(wireguard_received_bytes{name=~\"$peer\"}[$__rate_interval]))"; "{{name}} received")] ; "Bps"; 12; 6; 12; 9),
      timeseries(7; "Cumulative peer traffic"; [prom_target("sum by (interface, name) (wireguard_sent_bytes{name=~\"$peer\"})"; "{{name}} sent"), prom_target("sum by (interface, name) (wireguard_received_bytes{name=~\"$peer\"})"; "{{name}} received")] ; "bytes"; 0; 15; 12; 9),
      table(8; "Peer handshake state"; [prom_target("wireguard_latest_handshake_seconds{name=~\"$peer\"}"; "{{name}} / {{interface}}") | .instant=true | .range=false] ; "s"; 12; 15; 12; 9),
      row(102; "VPN service resources"; 24),
      timeseries(9; "WireGuard container CPU"; [prom_target("sum by (host, name) (rate(container_cpu_usage_seconds_total{name=\"wireguard-server\"}[$__rate_interval])) * 100"; "{{host}} / {{name}}")] ; "percent"; 0; 25; 12; 8),
      timeseries(10; "WireGuard container memory"; [prom_target("sum by (host, name) (container_memory_working_set_bytes{name=\"wireguard-server\"})"; "{{host}} / {{name}}")] ; "bytes"; 12; 25; 12; 8)
    ]);

def authelia:
  dashboard("serverpi-authelia"; "ServerPi / Authelia Authentication";
    "Authelia authentication, authorization, latency, and ban activity.";
    ["authelia", "authentication", "security"];
    [host_var("label_values(authelia_request, host)")];
    [
      row(100; "Authentication summary"; 0),
      stat(1; "Requests in range"; "sum(increase(authelia_request{host=~\"$host\"}[$__range]))"; "short"; 0; 1; 4),
      stat(2; "Successful first factor"; "sum(increase(authelia_authn{host=~\"$host\",success=\"true\"}[$__range]))"; "short"; 4; 1; 4),
      stat_bad(3; "Failed first factor"; "sum(increase(authelia_authn{host=~\"$host\",success=\"false\",banned=\"false\"}[$__range]))"; "short"; 8; 1; 4),
      stat_bad(4; "Banned attempts"; "sum(increase(authelia_authn{host=~\"$host\",banned=\"true\"}[$__range]))"; "short"; 12; 1; 4),
      stat(5; "p95 authentication latency"; "histogram_quantile(0.95, sum by (le) (rate(authelia_authn_duration_bucket{host=~\"$host\"}[$__rate_interval])))"; "s"; 16; 1; 4),
      stat_bad(6; "5xx responses"; "sum(increase(authelia_request{host=~\"$host\",code=~\"5..\"}[$__range]))"; "short"; 20; 1; 4),
      row(101; "Requests and latency"; 5),
      timeseries(7; "HTTP requests"; [prom_target("sum by (method, code) (rate(authelia_request{host=~\"$host\"}[$__rate_interval]))"; "{{method}} / {{code}}")] ; "reqps"; 0; 6; 12; 8),
      timeseries(8; "Request latency percentiles"; [prom_target("histogram_quantile(0.50, sum by (le) (rate(authelia_request_duration_bucket{host=~\"$host\"}[$__rate_interval])))"; "p50"), prom_target("histogram_quantile(0.95, sum by (le) (rate(authelia_request_duration_bucket{host=~\"$host\"}[$__rate_interval])))"; "p95"), prom_target("histogram_quantile(0.99, sum by (le) (rate(authelia_request_duration_bucket{host=~\"$host\"}[$__rate_interval])))"; "p99")] ; "s"; 12; 6; 12; 8),
      row(102; "Authentication and authorization"; 14),
      timeseries(9; "First-factor authentication rate"; [prom_target("sum by (success, banned) (rate(authelia_authn{host=~\"$host\"}[$__rate_interval]))"; "success={{success}} banned={{banned}}")] ; "reqps"; 0; 15; 12; 8),
      timeseries(10; "Second-factor authentication rate"; [prom_target("sum by (type, success, banned) (rate(authelia_authn_second_factor{host=~\"$host\"}[$__rate_interval]))"; "{{type}} success={{success}} banned={{banned}}")] ; "reqps"; 12; 15; 12; 8),
      timeseries(11; "Authorization decisions"; [prom_target("sum by (code) (rate(authelia_authz{host=~\"$host\"}[$__rate_interval]))"; "HTTP {{code}}")] ; "reqps"; 0; 23; 12; 8),
      timeseries(12; "Authentication latency by outcome"; [prom_target("histogram_quantile(0.95, sum by (success, le) (rate(authelia_authn_duration_bucket{host=~\"$host\"}[$__rate_interval])))"; "success={{success}} p95")] ; "s"; 12; 23; 12; 8),
      row(103; "Distributions"; 31),
      pie(13; "HTTP status distribution"; prom_target("sum by (code) (increase(authelia_request{host=~\"$host\"}[$__range]))"; "HTTP {{code}}") | .instant=true | .range=false; 0; 32; 8; 8),
      pie(14; "First-factor outcomes"; prom_target("sum by (success, banned) (increase(authelia_authn{host=~\"$host\"}[$__range]))"; "success={{success}} banned={{banned}}") | .instant=true | .range=false; 8; 32; 8; 8),
      pie(15; "Second-factor methods"; prom_target("sum by (type) (increase(authelia_authn_second_factor{host=~\"$host\",success=\"true\"}[$__range]))"; "{{type}}") | .instant=true | .range=false; 16; 32; 8; 8)
    ]);

def mail:
  dashboard("serverpi-mail"; "ServerPi / Docker Mailserver";
    "Dovecot OpenMetrics and Postfix log-derived metrics.";
    ["mail", "postfix", "dovecot"];
    [];
    [
      row(100; "Mail flow"; 0),
      stat(1; "Postfix messages sent"; "sum(increase(postfix_statuses_total{status=\"sent\"}[$__range]))"; "short"; 0; 1; 4),
      stat_bad(2; "Postfix messages deferred"; "sum(increase(postfix_statuses_total{status=\"deferred\"}[$__range]))"; "short"; 4; 1; 4),
      stat_bad(3; "Postfix messages bounced"; "sum(increase(postfix_statuses_total{status=\"bounced\"}[$__range]))"; "short"; 8; 1; 4),
      stat(4; "Dovecot deliveries"; "sum(increase(dovecot_mail_delivery_total[$__range]))"; "short"; 12; 1; 4),
      stat(5; "Dovecot auth successes"; "sum(increase(dovecot_auth_success_total[$__range]))"; "short"; 16; 1; 4),
      stat_bad(6; "Authentication failures"; "sum(increase(dovecot_auth_failure_total[$__range])) + sum(increase(postfix_login_failures_total[$__range]))"; "short"; 20; 1; 4),
      row(101; "SMTP and queue activity"; 5),
      timeseries(7; "Delivery status rate"; [prom_target("sum by (status) (rate(postfix_statuses_total[$__rate_interval]))"; "{{status}}")] ; "ops"; 0; 6; 12; 9),
      timeseries(8; "Postfix connections"; [prom_target("sum by (subprogram) (rate(postfix_connects_total[$__rate_interval]))"; "{{subprogram}} connects"), prom_target("sum by (subprogram) (rate(postfix_disconnects_total[$__rate_interval]))"; "{{subprogram}} disconnects")] ; "ops"; 12; 6; 12; 9),
      timeseries(9; "Queue manager events"; [prom_target("sum by (status) (rate(postfix_qmgr_statuses_total[$__rate_interval]))"; "{{status}}")] ; "ops"; 0; 15; 12; 9),
      timeseries(10; "Postfix rejects and postscreen actions"; [prom_target("sum by (action) (rate(postfix_postscreen_actions_total[$__rate_interval]))"; "postscreen {{action}}"), prom_target("sum(rate(postfix_noqueue_reject_replies_total[$__rate_interval]))"; "NOQUEUE rejects")] ; "ops"; 12; 15; 12; 9),
      row(102; "IMAP and authentication"; 24),
      timeseries(11; "Dovecot authentication rate"; [prom_target("rate(dovecot_auth_success_total[$__rate_interval])"; "success"), prom_target("rate(dovecot_auth_failure_total[$__rate_interval])"; "failure")] ; "ops"; 0; 25; 12; 8),
      timeseries(12; "IMAP commands by result"; [prom_target("sum by (cmd_name, tagged_reply_state) (rate(dovecot_imap_command_total{tagged_reply_state!=\"\"}[$__rate_interval]))"; "{{cmd_name}} / {{tagged_reply_state}}")] ; "ops"; 12; 25; 12; 8),
      timeseries(13; "IMAP command average duration"; [prom_target("sum by (cmd_name) (rate(dovecot_imap_command_duration_seconds_total{tagged_reply_state=\"\"}[$__rate_interval])) / clamp_min(sum by (cmd_name) (rate(dovecot_imap_command_total{tagged_reply_state=\"\"}[$__rate_interval])), 1e-9)"; "{{cmd_name}}")] ; "s"; 0; 33; 12; 8),
      timeseries(14; "Dovecot delivery and session activity"; [prom_target("rate(dovecot_mail_delivery_total[$__rate_interval])"; "deliveries"), prom_target("rate(dovecot_mail_session_total[$__rate_interval])"; "completed mail sessions")] ; "ops"; 12; 33; 12; 8)
    ]);

def wordpress:
  dashboard("serverpi-wordpress"; "ServerPi / WordPress";
    "WordPress application, content, update, Site Health, storage, PHP, database, and autoload telemetry from SlyMetrics.";
    ["wordpress", "slymetrics", "application"];
    [query_var("wordpress_site"; "Site"; "label_values(wordpress_version, wordpress_site)")];
    [
      row(100; "Application health"; 0),
      stat_bad(1; "Exporter down"; "1 - max(up{job=\"wordpress\"})"; "short"; 0; 1; 4),
      stat_bad(2; "Plugin updates available"; "sum(wordpress_plugins_update_total{wordpress_site=~\"$wordpress_site\",status=\"available\"})"; "short"; 4; 1; 4),
      stat_bad(3; "Critical health checks"; "sum(wordpress_health_check_total{wordpress_site=~\"$wordpress_site\",category=\"critical\"})"; "short"; 8; 1; 4),
      stat_bad(4; "Recommended health checks"; "sum(wordpress_health_check_total{wordpress_site=~\"$wordpress_site\",category=\"recommended\"})"; "short"; 12; 1; 4),
      stat(5; "Database size"; "sum(wordpress_database_size_bytes{wordpress_site=~\"$wordpress_site\"})"; "bytes"; 16; 1; 4),
      stat_bad(6; "Autoloaded option size"; "sum(wordpress_autoload_size_bytes{wordpress_site=~\"$wordpress_site\"})"; "bytes"; 20; 1; 4),
      row(101; "Content and updates"; 5),
      timeseries(7; "Posts and pages by status"; [prom_target("wordpress_posts_total{wordpress_site=~\"$wordpress_site\"}"; "posts / {{status}}"), prom_target("wordpress_pages_total{wordpress_site=~\"$wordpress_site\"}"; "pages / {{status}}")] ; "short"; 0; 6; 12; 8),
      timeseries(8; "Comments by status"; [prom_target("wordpress_comments_total{wordpress_site=~\"$wordpress_site\"}"; "{{status}}")] ; "short"; 12; 6; 12; 8),
      timeseries(9; "Plugins by state"; [prom_target("wordpress_plugins_total{wordpress_site=~\"$wordpress_site\"}"; "{{status}}"), prom_target("wordpress_plugins_update_total{wordpress_site=~\"$wordpress_site\"}"; "updates / {{status}}")] ; "short"; 0; 14; 12; 8),
      timeseries(10; "Content inventory"; [prom_target("wordpress_media_total{wordpress_site=~\"$wordpress_site\"}"; "media"), prom_target("wordpress_categories_total{wordpress_site=~\"$wordpress_site\"}"; "categories"), prom_target("wordpress_tags_total{wordpress_site=~\"$wordpress_site\"}"; "tags"), prom_target("wordpress_users_total{wordpress_site=~\"$wordpress_site\"}"; "users / {{role}}")] ; "short"; 12; 14; 12; 8),
      row(102; "Capacity and runtime"; 22),
      timeseries(11; "WordPress directory sizes"; [prom_target("wordpress_directory_size_bytes{wordpress_site=~\"$wordpress_site\"}"; "{{directory}}")] ; "bytes"; 0; 23; 12; 8),
      timeseries(12; "Database and autoload size"; [prom_target("wordpress_database_size_bytes{wordpress_site=~\"$wordpress_site\"}"; "database"), prom_target("wordpress_autoload_size_bytes{wordpress_site=~\"$wordpress_site\"}"; "autoload options")] ; "bytes"; 12; 23; 12; 8),
      timeseries(13; "Autoloaded options"; [prom_target("wordpress_autoload_options_total{wordpress_site=~\"$wordpress_site\"}"; "options"), prom_target("wordpress_autoload_transients_total{wordpress_site=~\"$wordpress_site\"}"; "transients")] ; "short"; 0; 31; 12; 8),
      table(14; "WordPress and PHP versions"; [prom_target("wordpress_version{wordpress_site=~\"$wordpress_site\"}"; "WordPress") | .instant=true | .range=false, prom_target("wordpress_php_version_info{wordpress_site=~\"$wordpress_site\"}"; "PHP") | .instant=true | .range=false] ; "short"; 12; 31; 12; 8)
    ]);

if $dashboard == "fleet" then fleet
elif $dashboard == "hosts" then hosts
elif $dashboard == "docker" then docker_services
elif $dashboard == "edge" then edge
elif $dashboard == "observability" then observability
elif $dashboard == "wireguard" then wireguard
elif $dashboard == "authelia" then authelia
elif $dashboard == "mail" then mail
elif $dashboard == "wordpress" then wordpress
else error("unknown dashboard: " + $dashboard)
end
