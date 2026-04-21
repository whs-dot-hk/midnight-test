# Setup
## Terraform state

| Key | Value |
| --- | --- |
| S3 bucket name | midnight-test-tf-state |
| DynamoDB table name | midnight-test-tf-state-lock |

# Nix shell with npins

```sh
nix-shell
```

# Terraform Stacks

* The stack `vpc` need to apply first; other can be in different order

| Stack | Description |
| --- | --- |
| `vpc` | Provisions the core VPC networking resources. |
| `amp` | Provisions an Amazon Managed Service for Prometheus workspace and Alertmanager SNS routing (`sns_critical`/`sns_warning`). |
| `aurora-cardano-db-sync` | Provisions an Aurora Serverless v2 database cluster for Cardano DB Sync. |
| `ec2-cardano-db-sync` | Provisions an EC2 instance and security group for Cardano DB Sync. |
| `ec2-midnight-node` | Provisions an EC2 instance and security group for a Midnight (Substrate) node intended for setup and operation in validator mode. |

# Section 1 — Node Setup: Become an FNO on Pre-Prod

See notes/RUNBOOK.md


# Section 2 — Monitoring & Alerting (Telemetry)

Prometheus rules in `monitoring/alerts.yml`; metric contract in `monitoring/README.md`. Workspace and SNS routing come from the `amp` stack. Optional checks: `scripts/node_health_checker.py`.

### Validator-duty alerts

| Alert | Description | Reasoning |
| --- | --- | --- |
| `MidnightValidatorJailed` | Jailed (`validator_jailed == 1`); `for: 5m`. | Avoid penalties; unjail via `notes/RUNBOOK.md` and verify validator status. |
| `MidnightValidatorNotSigning` | No signed blocks in 30m (`increase(validator_signed_blocks_total[30m]) == 0`); `for: 5m`. | Prevent missed duties; check keys, signer process, validator role, and consensus connectivity. |
| `MidnightValidatorLowSigningRate` | Signing rate below threshold (`rate(validator_signed_blocks_total[30m]) < 0.01`); `for: 10m`. | Early warning before full signing outage; tune threshold and check node performance/connectivity. |

# Section 3 — Automation & Scripting: Node Health Checker (Option C)

* Jsonl format
* Auto rotate
* Check both metrics and json-rpc

Script path: `scripts/node_health_checker.py`

Polls RPC and/or metrics endpoints and writes a JSON report with `healthy|unhealthy` status.

Minimum usage:

```sh
uv run python scripts/node_health_checker.py \
  --metrics-endpoint http://127.0.0.1:9615/metrics \
  --report-path notes/midnight-node-health.json \
  --iterations 1
```

Common Midnight continuous check:

```sh
uv run python scripts/node_health_checker.py \
  --rpc-endpoint http://127.0.0.1:9944 \
  --metrics-endpoint http://127.0.0.1:9615/metrics \
  --report-path notes/midnight-node-health.json \
  --check result.peers,1 \
  --require-metric substrate_block_height \
  --monotonic-metric substrate_block_height \
  --interval-seconds 30 \
  --iterations 0
```

Notes:
- At least one endpoint is required: `--rpc-endpoint` or `--metrics-endpoint`.
- `--check` format is `json.path,value` and uses strict `>`.
- `--metric-threshold` format is `metric,value` and uses strict `>`.
- Previous report defaults to `--report-path` unless `--previous-report-path` is set.

# Section 4 — Security & Key Management

See notes/SECURITY.md

# If more time

I think I am able to run a Midnight node (Validator mode), but I am not able to get it to connect to other peers (which is intented as it should be in private subnet); so I think the metrics is not complete; therefore I cannnot fully test the script and the prometheus dashboard.
