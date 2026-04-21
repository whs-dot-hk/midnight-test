# Cardano DB Sync Setup

Reference: https://midnightfoundation.notion.site/FNO-Setup-Cardano-Preprod-Availability-3374057b9f23803792b3fa26ee9bdbc1

## Install Mithril signer, client and aggregator

Reference: https://github.com/input-output-hk/mithril/releases

> TODO: DO NOT use ubuntu user; create a least privilege user.

The instance `midnight-test-ec2-cardano-db-sync` can only login with SSM

```
sudo su ubuntu
mkdir -p $HOME/tmp/mithril && cd $HOME/tmp/mithril

# Install mithril-signer
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-signer -d unstable -p $(pwd)

# Install mithril-client
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-client -d unstable -p $(pwd)

# Install mithril-aggregator
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-aggregator -d unstable -p $(pwd)
```

## Export Preprod environment variables

Reference: https://mithril.network/doc/manual/getting-started/network-configurations/ (see Preprod tab)

```sh
export CARDANO_NETWORK=preprod
export AGGREGATOR_ENDPOINT=https://aggregator.release-preprod.api.mithril.network/aggregator
export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
export ANCILLARY_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/ancillary.vkey)
export SNAPSHOT_DIGEST=latest
```

## Download snapshot with mithril

```sh
# List snapshots
./mithril-client cardano-db snapshot list

# Show latest snapshot
./mithril-client cardano-db snapshot show $SNAPSHOT_DIGEST
Mithril Client CLI version: 0.13.7+3b3d1ba
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Epoch                   | 283         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Immutable File Number   | 5598         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Hash                    | dbedc94db4e49c8404139cad2764585050d1afffbc489ede069d11770efd88f3         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Merkle root             | ad03c6862ea352cc85f320565e8f8749092a2abb9024c1c8bb6c7e001256076f         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Database size           | 16.52 GiB         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Cardano node version    | 10.6.2         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Digest location (1)     | CloudStorage, uri: "https://storage.googleapis.com/cdn.aggregator.release-preprod.api.mithril.network/cardano-database/digests/preprod-e283-i5598.digests.tar.zst"         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Digest location (2)     | Aggregator, uri: "https://aggregator.release-preprod.api.mithril.network/aggregator/artifact/cardano-database/digests"         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Immutables location (1) | CloudStorage, template_uri: "https://storage.googleapis.com/cdn.aggregator.release-preprod.api.mithril.network/cardano-database/immutable/{immutable_file_number}.tar.zst" |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Ancillary location (1)  | CloudStorage, uri: "https://storage.googleapis.com/cdn.aggregator.release-preprod.api.mithril.network/cardano-database/ancillary/preprod-e283-i5598.ancillary.tar.zst"     |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Created                 | 2026-04-20 10:26:24.285147186 UTC         |
+-------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

# Download the latest snapshot; the snapshot size is much smaller than our disk size so we are safe to download
./mithril-client cardano-db download --include-ancillary $SNAPSHOT_DIGEST
Mithril Client CLI version: 0.13.7+3b3d1ba
Warning: Ancillary verification does not use the Mithril certification: as a mitigation, IOG owned keys are used to sign these files.
1/7 - Checking local disk info…2/7 - Fetching the certificate and verifying the certificate chain…  Certificate chain validated3/7 - Downloading and unpacking the cardano db snapshot
4/7 - Downloading and verifying digests…5/7 - Verifying the cardano database6/7 - Computing the cardano db snapshot message7/7 - Verifying the cardano db signature…Cardano database snapshot 'dbedc94db4e49c8404139cad2764585050d1afffbc489ede069d11770efd88f3' archives have been successfully unpacked. Immutable files have been successfully verified with Mithril.

    Files in the directory 'db' can be used to run a Cardano node with version >= 10.6.2.

If you are using the Cardano Docker image, you can restore a Cardano node with:

    docker run -v cardano-node-ipc:/ipc -v cardano-node-data:/data --mount type=bind,source="/home/ubuntu/tmp/mithril/db",target=/data/db/ -e NETWORK=preprod ghcr.io/intersectmbo/cardano-node:10.6.2


Upgrade and replace the restored ledger state snapshot to 'LMDB' flavor by running the command:

    mithril-client tools utxo-hd snapshot-converter --db-directory db --cardano-node-version 10.6.2 --utxo-hd-flavor LMDB --commit
```

## Download cardano-node binary

```sh
mkdir -p ~/.local/bin ~/.local/share

VERSION="10.6.4" # Use latest version
ARCH="linux-amd64"
URL="https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-${ARCH}.tar.gz"

curl -L "$URL" | tar -xz -C ~/.local/bin --strip-components=2 ./bin
curl -L "$URL" | tar -xz -C ~/.local/share --strip-components=2 ./share

chmod +x ~/.local/bin/cardano-*

export PATH="$HOME/.local/bin:$PATH"

cardano-node --version
cardano-node 10.6.4 - linux-x86_64 - ghc-9.6
git rev 5a4dcd1b410ba78f9faab7acd48f606496909935
```

## Create data directory

> TODO: We should mount another disk to `~/cardano-data/` directory; for ebs snapshot

```sh
mkdir ~/cardano-data
mv ~/tmp/mithril/db/ ~/cardano-data/
```

## Create systemd service for cardano-node (replay)

> TODO: DO NOT use ubuntu user; create a least privilege user

```txt
# /etc/systemd/system/cardano-node.service
[Unit]
Description=Cardano Relay Node (Preprod)
Wants=network-online.target
After=network-online.target

[Service]
User=ubuntu
Type=simple
WorkingDirectory=/home/ubuntu/cardano-data
ExecStart=/home/ubuntu/.local/bin/cardano-node run \
    --topology /home/ubuntu/.local/share/preprod/topology.json \
    --database-path /home/ubuntu/cardano-data/db \
    --socket-path /home/ubuntu/cardano-data/db/node.socket \
    --host-addr 0.0.0.0 \
    --port 3001 \
    --config /home/ubuntu/.local/share/preprod/config.json
KillSignal=SIGINT
Restart=always
RestartSec=5
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
```

```
sudo systemctl daemon-reload
sudo systemctl enable --now cardano-node
```

## Install psql client

```sh
sudo apt update
sudo apt install -y postgresql-client
```

## Setup midnight db user

> Note: the db password can be found in secrets manager

```sh
# Connect to the aurora db
psql -h midnight-test-aurora-cardano-db-sync-instance-1.clllairbmleh.us-east-1.rds.amazonaws.com -U dbadmin -d postgres
```

```txt
CREATE USER midnight WITH PASSWORD 'your_secure_password';
CREATE DATABASE cexplorer;
GRANT ALL PRIVILEGES ON DATABASE cexplorer TO midnight;
\c cexplorer
GRANT USAGE, CREATE ON SCHEMA public TO midnight;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO midnight;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO midnight;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO midnight;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO midnight;
```

```sh
export POSTGRES_PASSWORD='your_secure_password'
export PGPASSFILE="${HOME}/.pgpass"
export AURORA_HOST='midnight-test-aurora-cardano-db-sync-instance-1.clllairbmleh.us-east-1.rds.amazonaws.com'
export AURORA_PORT='5432'
export AURORA_DB='cexplorer'
export AURORA_USER='midnight'

echo "${AURORA_HOST}:${AURORA_PORT}:${AURORA_DB}:${AURORA_USER}:${POSTGRES_PASSWORD}" > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"
```

## Setup cardano-db-sync

```sh
NETWORK="preprod"
mkdir -p ~/tmp && cd ~/tmp
curl -L -O https://github.com/IntersectMBO/cardano-db-sync/releases/download/13.6.0.7/cardano-db-sync-13.6.0.7-linux.tar.gz
tar -xzf cardano-db-sync-13.6.0.7-linux.tar.gz

cp bin/* ~/.local/bin/
mkdir -p ~/cardano-data/
sudo mv ~/tmp/schema ~/cardano-data/

cd ~/cardano-data
curl -O https://book.world.dev.cardano.org/environments/$NETWORK/db-sync-config.json
sed -i "s|\"NodeConfigFile\": \"config.json\"|\"NodeConfigFile\": \"/home/ubuntu/.local/share/$NETWORK/config.json\"|" ~/cardano-data/db-sync-config.json
```


## Create cardano-db-sync service

> TODO: DO NOT use ubuntu user; create a least privilege user

```txt
# /etc/systemd/system/cardano-db-sync.service
[Unit]
Description=Cardano DB Sync (Preprod)
After=cardano-node.service
Requires=cardano-node.service

[Service]
User=ubuntu
Type=simple
Environment="PGPASSFILE=/home/ubuntu/.pgpass"
WorkingDirectory=/home/ubuntu/cardano-data
ExecStart=/home/ubuntu/.local/bin/cardano-db-sync \
    --config /home/ubuntu/cardano-data/db-sync-config.json \
    --socket-path /home/ubuntu/cardano-data/db/node.socket \
    --schema-dir /home/ubuntu/cardano-data/schema \
    --state-dir /home/ubuntu/cardano-data/db-sync-state
KillSignal=SIGINT
Restart=always
RestartSec=10
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now cardano-db-sync
```

## Verify
```sql
\c cexplorer
SELECT block_no, slot_no, time FROM block ORDER BY id DESC LIMIT 1;
SELECT
    100 * (EXTRACT(epoch FROM (MAX(time) AT TIME ZONE 'UTC')) - EXTRACT(epoch FROM (MIN(time) AT TIME ZONE 'UTC')))
    / (EXTRACT(epoch FROM (NOW() AT TIME ZONE 'UTC')) - EXTRACT(epoch FROM (MIN(time) AT TIME ZONE 'UTC')))
AS sync_percent
FROM block;
```

```sh
export CARDANO_NODE_SOCKET_PATH=/home/ubuntu/cardano-data/db/node.socket
cardano-cli conway query tip --testnet-magic 1 | jq
{
  "block": 4628034,
  "epoch": 283,
  "era": "Conway",
  "hash": "2b90f24d5eb5c25fe2489baa46ba1e9d8e398d2bae6aa79f698ad9a6ab2a0687",
  "slot": 121033501,
  "slotInEpoch": 419101,
  "slotsToEpochEnd": 12899,
  "syncProgress": "100.00"
}
```

# Midnight Node Setup

Reference: https://midnightfoundation.notion.site/FNO-Install-Midnight-Node-and-Generate-Validator-Keys-Preprod-3374057b9f2380939d19e37600648212

## Install midnight-node

```sh
# Prepare directories
mkdir -p ~/data ~/.local/bin

# Download and extract the node 0.22.3
mkdir -p ~/tmp && cd ~/tmp
curl -L -O https://github.com/midnightntwrk/midnight-node/releases/download/node-0.22.3/midnight-node-0.22.3-linux-amd64.tar.gz
tar -xvzf midnight-node-0.22.3-linux-amd64.tar.gz

# Move files to target locations
mv ~/tmp/midnight-node ~/.local/bin/
mv ~/tmp/res ~/
```

## Generate session keys

> TODO: More secure way to generate keys

```sh
export PATH="$HOME/.local/bin:$PATH"

cd ~

# Generate AURA (sr25519)
midnight-node key generate --scheme sr25519 --output-type json > aura.json

# Generate GRANDPA (ed25519)
midnight-node key generate --scheme ed25519 --output-type json > grandpa.json

# Generate CROSS-CHAIN (ecdsa)
midnight-node key generate --scheme ecdsa --output-type json > cross_chain.json
```

## Generate network keys


```
cp res/cfg/default.toml res/cfg/default.toml.bak
cat res/cfg/preprod.toml res/cfg/default.toml.bak > res/cfg/default.toml
```

The file `~/res/cfg/preprod.toml` should look something like this

```toml
chain = "res/preprod/chain-spec-raw.json"
base_path = "node/chain"

chainspec_name = "Midnight Preprod"
chainspec_id = "midnight_preprod"
chainspec_genesis_state = "res/genesis/genesis_state_preprod.mn"
chainspec_genesis_block = "res/genesis/genesis_block_preprod.mn"
chainspec_chain_type = "live"
chainspec_pc_chain_config = "res/preprod/pc-chain-config.json"
chainspec_cnight_genesis = "res/preprod/cnight-config.json"
chainspec_ics_config = "res/preprod/ics-config.json"
chainspec_reserve_config = "res/preprod/reserve-config.json"
chainspec_federated_authority_config = "res/preprod/federated-authority-config.json"
chainspec_system_parameters_config = "res/preprod/system-parameters-config.json"
chainspec_permissioned_candidates_config = "res/preprod/permissioned-candidates-config.json"
chainspec_registered_candidates_addresses = "res/preprod/registered-candidates-addresses.json"

cardano_security_parameter = 2160
cardano_active_slots_coeff = 0.05
block_stability_margin = 10

mc__first_epoch_timestamp_millis = 1655769600000
mc__first_epoch_number = 4
mc__epoch_duration_millis = 432000000
mc__first_slot_number = 86400
mc__slot_duration_millis = 1000
# Values in this file are defaults for testnet
# TODO: Add values for:
# - chain_id
# - threshold_numerator
# - threshold_denominator
# - genesis_committee_utxo
# - governance_authority

wipe_chain_state = false
use_main_chain_follower_mock = false
show_config = false
show_secrets = false
validator = false

# DO NOT SET THE BASE_PATH HERE
# This is done in the Earthfile and is set to /node/chain
# base_path = "/node/chain"

# MidnightEnv Defaults
#cardano_security_parameter = 432
#cardano_active_slots_coeff = 0.05
#block_stability_margin = 10
#
#mc__first_epoch_timestamp_millis = 1666656000000
#mc__first_epoch_number = 0
#mc__epoch_duration_millis = 86400000
#mc__first_slot_number = 0
#mc__slot_duration_millis = 1000
allow_non_ssl = false

# Memory Monitor Defaults (MiB)
# Set memory_threshold > 0 to enable. On Linux, checks cgroup limits then /proc/meminfo.
memory_threshold = 0
memory_polling_period = 1

# Storage Monitor Defaults
threshold = 512
polling_period = 5

# Storage cache size = measured in number of storage nodes
# Setting of 0 means storage cache size is unlimited.
# Will cause OOM errors if too much data is loaded.

# Setting to a non-default value derived from the DEFAULT_CACHE_SIZE of the midnight-ledger crate:
# https://github.com/midnightntwrk/midnight-ledger/blob/ledger-7.0.0-rc.2/storage/src/storage.rs#L54
storage_cache_size = 10000

# Set to default: 1024 * 1024 * 1024
trie_cache_size = 1073741824

argv = []
args = []
append_args = []
bootnodes = []
```

```sh
NETWORK="preprod"
NETWORK_DIR="$HOME/data/chains/midnight_${NETWORK}/network"
mkdir -p "$NETWORK_DIR"
chmod 700 "$NETWORK_DIR"

midnight-node key generate-node-key --file "$NETWORK_DIR/secret_ed25519"
12D3KooWHKKNifzYaCSEZ2R6AjSkxR3SbJGCb6C3zvhiJ6kBj57o


# Inpsect peer id; output should be same as above
midnight-node key inspect-node-key --file "$NETWORK_DIR/secret_ed25519"
```

## Configure key store

```sh
KEYSTORE_PATH="$HOME/data/chains/midnight_preprod/keystore"
mkdir -p "$KEYSTORE_PATH"

# Insert AURA key
midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme sr25519 \
  --key-type aura \
  --suri $(jq -r .secretPhrase aura.json)

# Insert GRANDPA key
midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme ed25519 \
  --key-type gran \
  --suri "$(jq -r .secretPhrase grandpa.json)"

# Insert Cross-Chain key
midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme ecdsa \
  --key-type beef \
  --suri "$(jq -r .secretPhrase cross_chain.json)"
```

## Register as Federated Node Operator
```sh
OUTPUT_FILE="$HOME/partner-chains-public-keys.json"

cat <<EOF > "$OUTPUT_FILE"
{
  "partner_chains_key": "$(jq -r .publicKey cross_chain.json)",
  "keys": {
    "aura": "$(jq -r .publicKey aura.json)",
    "crch": "$(jq -r .publicKey cross_chain.json)",
    "gran": "$(jq -r .publicKey grandpa.json)"
  }
}
EOF

cat "$OUTPUT_FILE"
```

# Setup Wireguard

## Install Wireguard (Version v1.0.20250521; required by Midnight)

```sh
sudo apt update && sudo apt install -y \
    git \
    build-essential \
    pkg-config \
    libelf-dev \
    linux-headers-$(uname -r)

# Define version and create workspace
WIREGUARD_TOOLS_VERSION="v1.0.20250521"
WORKDIR="$(mktemp -d)"

# Clone and build
git clone https://git.zx2c4.com/wireguard-tools "$WORKDIR/wireguard-tools"
cd "$WORKDIR/wireguard-tools"
git checkout "$WIREGUARD_TOOLS_VERSION"
make -C src && sudo make -C src install

# Verify installation
wg --version
```

## Generate Wireguard keys

```sh
umask 077

# Generate keys
wg genkey | tee privatekey | wg pubkey > publickey

cat publickey
hrxt67lC787vrqTra5uE+GFeKv0kUfpcNnzIjdZJjHc=
```

## Send to Midnight Foundation (fill in the form)

> Note: Substrate Network Key (Node Identity) have been generated

![Form response](./form-response.png)

# Run Midnight node in Validator Mode

Reference: https://midnightfoundation.notion.site/FNO-Run-Midnight-Node-in-Validator-Mode-Preprod-3374057b9f238081a377fc6a1219e8e7

Make sure the cardano-db-sync is in sync

```sh
cexplorer=> SELECT
    100 * (EXTRACT(epoch FROM (MAX(time) AT TIME ZONE 'UTC')) - EXTRACT(epoch FROM (MIN(time) AT TIME ZONE 'UTC')))
    / (EXTRACT(epoch FROM (NOW() AT TIME ZONE 'UTC')) - EXTRACT(epoch FROM (MIN(time) AT TIME ZONE 'UTC')))
AS sync_percent
FROM block;
    sync_percent
---------------------
 99.9999980123562853
(1 row)
```

The `~/.env` file

> TODO: Check if can connect to read-only endpoint of Psostgres; midnight user password share through 1Password; keystore should not be in plaintext

> Important: Edit the files /home/ubuntu/data/chains/midnight_preprod/keystore/{61757261c45d8201496a08afdcd8dc99514f01ea2556490ff033e44259d6b947d749e313, 6772616e730cf073c886a337d0caa75ebe3da8155d433d855e0c725213438d48fafab649, 626565660225105cf2617a17071f9582edee37f713d5c7b030e74c6eea8fb5f976d67e3c30} to remove double quotes

```txt
export POSTGRES_HOST='midnight-test-aurora-cardano-db-sync-instance-1.clllairbmleh.us-east-1.rds.amazonaws.com'
export POSTGRES_DB='cexplorer'
export POSTGRES_PORT=5432
export POSTGRES_USER='midnight'
export POSTGRES_PASSWORD='YOUR_POSTGRES_PASSWORD'
export DB_SYNC_POSTGRES_CONNECTION_STRING=postgresql://midnight:YOUR_POSTGRES_PASSWORD@midnight-test-aurora-cardano-db-sync-instance-1.clllairbmleh.us-east-1.rds.amazonaws.com:5432/cexplorer

# Cardano Preprod params
#CARDANO_SECURITY_PARAMETER='432'
export BLOCK_STABILITY_MARGIN=30

# Push to public telemetry
export PROMETHEUS_PUSH_ENDPOINT='https://telemetry.shielded.tools/api/v1/receive'

# Midnight node settings
export CFG_PRESET=preprod
export NODE_NAME='HENRY_WONG_MIDNIGHT_NODE'

# Absolute path to network and keystore files
export NODE_KEY_FILE='/home/ubuntu/data/chains/midnight_preprod/network/secret_ed25519'
export AURA_SEED_FILE='/home/ubuntu/data/chains/midnight_preprod/keystore/61757261c45d8201496a08afdcd8dc99514f01ea2556490ff033e44259d6b947d749e313'
export GRANDPA_SEED_FILE='/home/ubuntu/data/chains/midnight_preprod/keystore/6772616e730cf073c886a337d0caa75ebe3da8155d433d855e0c725213438d48fafab649'
export CROSS_CHAIN_SEED_FILE='/home/ubuntu/data/chains/midnight_preprod/keystore/626565660225105cf2617a17071f9582edee37f713d5c7b030e74c6eea8fb5f976d67e3c30'
```

## Start Midnight Node

> TODO: Setup midnight local user to run midnight node

```sh
source ~/.env

export PATH="$HOME/.local/bin:$PATH"

midnight-node \
    --chain /home/ubuntu/res/preprod/chain-spec-raw.json \
    --base-path /home/ubuntu/data \
    --telemetry-url 'wss://telemetry.shielded.tools./submit 1' \
    --validator \
    --pool-limit 35 \
    --name ${NODE_NAME} \
    --rpc-port 9933
```

![Midnight node start](./midnight-node-start.png)

![Midnight node running](./midnight-node-running.png)
