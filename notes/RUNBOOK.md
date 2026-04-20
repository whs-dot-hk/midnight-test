# Cardano DB Sync setup

Reference: https://midnightfoundation.notion.site/FNO-Setup-Cardano-Preprod-Availability-3374057b9f23803792b3fa26ee9bdbc1

## Install Mithril signer, client and aggregator

Reference: https://github.com/input-output-hk/mithril/releases

TODO: DO NOT use ubuntu user; create a least privilege user.

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

TODO: We should mount another disk to `~/cardano-data/` directory; for ebs snapshot

```sh
mkdir ~/cardano-data
mv ~/tmp/mithril/db/ ~/cardano-data/
```

## Create systemd service for cardano-node (replay)

TODO: DO NOT use ubuntu user; create a least privilege user

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

Note: the db password can be found in secrets manager

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

TODO: DO NOT use ubuntu user; create a least privilege user

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
