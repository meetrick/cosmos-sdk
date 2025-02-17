#!/usr/bin/env bash

SIMD_BIN=${SIMD_BIN:=$(which simdv2 2>/dev/null)}

if [ -z "$SIMD_BIN" ]; then echo "SIMD_BIN is not set. Make sure to run 'COSMOS_BUILD_OPTIONS=v2 make install' before"; exit 1; fi
echo "using $SIMD_BIN"
SIMD_HOME=$($SIMD_BIN config home)
if [ -d "$SIMD_HOME" ]; then rm -rv $SIMD_HOME; fi
$SIMD_BIN config set client chain-id simapp-v2-chain
$SIMD_BIN config set client keyring-backend test
$SIMD_BIN config set client keyring-default-keyname alice
$SIMD_BIN config set app rest.enable true
$SIMD_BIN config set app telemetry.prometheus-retention-time 600
$SIMD_BIN config set app store.options.sc-type iavl-v2
sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/' "$SIMD_HOME"/config/config.toml
sed -i '' 's/prometheus = false/prometheus = true/' "$SIMD_HOME"/config/config.toml

$SIMD_BIN keys add alice --indiscreet
$SIMD_BIN keys add bob --indiscreet
aliases=""
for i in $(seq 10); do
    alias=$(dd if=/dev/urandom bs=16 count=24 2> /dev/null | base32 | head -c 32)
    $SIMD_BIN keys add "$alias" --indiscreet
    aliases="$aliases $alias"
done
echo "Generated aliases: $aliases"

$SIMD_BIN init simapp-v2-node --chain-id simapp-v2-chain
# to change the voting_period
jq '.app_state.gov.params.voting_period = "600s"' $SIMD_HOME/config/genesis.json > temp.json && mv temp.json $SIMD_HOME/config/genesis.json
jq '.app_state.gov.params.expedited_voting_period = "300s"' $SIMD_HOME/config/genesis.json > temp.json && mv temp.json $SIMD_HOME/config/genesis.json
jq '.app_state.mint.minter.inflation = "0.300000000000000000"' $SIMD_HOME/config/genesis.json > temp.json && mv temp.json $SIMD_HOME/config/genesis.json # to change the inflation
$SIMD_BIN genesis add-genesis-account alice 5000000000stake --keyring-backend test
$SIMD_BIN genesis add-genesis-account bob 5000000000stake --keyring-backend test
for a in $aliases; do
    $SIMD_BIN genesis add-genesis-account "$a" 100000000stake --keyring-backend test
done
$SIMD_BIN genesis gentx alice 1000000stake --chain-id simapp-v2-chain
$SIMD_BIN genesis collect-gentxs