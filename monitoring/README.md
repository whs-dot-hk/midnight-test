# Monitoring Assets

## Add IAM policy
We need to add a `AWS managed` policy  `AmazonPrometheusRemoteWriteAccess` to the role for the midnight node ec2 instance.

## Install Prometheus

```sh
sudo apt update
sudo apt install -y prometheus
```

## Install aws-sigv4-proxy
```sh
sudo apt install -y git golang-go make

cd /tmp
git clone https://github.com/awslabs/aws-sigv4-proxy.git
cd /tmp/aws-sigv4-proxy

go build -o aws-sigv4-proxy ./cmd/aws-sigv4-proxy

sudo install -m 0755 aws-sigv4-proxy /usr/local/bin/aws-sigv4-proxy

/usr/local/bin/aws-sigv4-proxy --help
```

## Create aws-sigv4-proxy service
```sh
sudo useradd --system --no-create-home --shell /usr/sbin/nologin sigv4proxy || true

sudo tee /etc/systemd/system/aws-sigv4-proxy.service >/dev/null <<'EOF'
[Unit]
Description=AWS SigV4 Proxy for APS remote_write
After=network-online.target
Wants=network-online.target

[Service]
User=sigv4proxy
Group=sigv4proxy
ExecStart=/usr/local/bin/aws-sigv4-proxy \
  --name aps \
  --region us-east-1 \
  --host aps-workspaces.us-east-1.amazonaws.com \
  --port 127.0.0.1:8005
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now aws-sigv4-proxy
```

## Edit Prometheus config

Edit file `/etc/prometheus/prometheus.yml` to

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: "midnight-validator"

alerting:
  alertmanagers: []

rule_files: null

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "midnight-node"
    metrics_path: /metrics
    static_configs:
      - targets: ["localhost:9615"]

remote_write:
  - url: "http://127.0.0.1:8005/workspaces/ws-db369357-796f-44ac-9d5f-40a26f246c75/api/v1/remote_write"
    sigv4:
      region: "us-east-1"
```

This is a must have dashboard for prometheus
https://grafana.com/grafana/dashboards/1860-node-exporter-full/


This directory contains telemetry alert definitions for the pre-prod Midnight validator node.

## Files

- `alerts.yml`: Prometheus-compatible alert rules focused on actionable node health signals.
- `midnight-node-dashboard.json`: Grafana dashboard for Midnight node health and validator activity.

## Dashboard import

1. Open Grafana and go to `Dashboards` -> `Import`.
2. Upload `monitoring/midnight-node-dashboard.json`.
3. Select your Prometheus data source.
4. Save the dashboard.

## Dashboard details
* Contains peers info
* Blocks info
* Custom metrics validator_jailed
* Custom metrics validator_signed_blocks_total
* Block height etc

The goal of the dashboard is for easy troubleshooting. It is also good to have a dashboard which contains multiple midnight node. So we can compare; for example the view of block height of all midnight nodes over time.

## Alerts details
* Node stops producing blocks is useful; receiving blocks may not.
* Peer count drops below a threshold; this one do not need to be alert but need to be warning; because peer drops always happen.
* Memory or CPU crosses a threshold useless to alert; can use a program to auto recovery
* Process crash / service restart do not need to be alert; because it is the same as not production blocks

The alert should only keep the useful ones to prevent fatigue.

## Notes

- The validator alert set includes three custom-metric alerts: `MidnightValidatorJailed`, `MidnightValidatorNotSigning`, and `MidnightValidatorLowSigningRate`.
- These alerts use `validator_jailed` and `validator_signed_blocks_total`; if your exporter does not expose them, wire them from your validator status endpoint or a lightweight sidecar script.

Reference: https://github.com/paritytech/polkadot-sdk/blob/master/substrate/client/consensus/beefy/README.md

More about the metrics can be find here: https://github.com/luislucena16/midnight-validator-dashboard/tree/main/app/api
For example uptime, connect peers, etc
