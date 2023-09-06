#! /usr/bin/env bash

## In the format of:
# HOSTS+=("adm")
# HOSTS+=("lgm")

source .env_hosts || exit

for h in "${HOSTS[@]}"; do
    echo "Syncing ${h} DOWN"
    rsync -ral "${h}":/sf/config/db/banned "${h}":/sf/config/db/token "${h}":/sf/config/db/limits .
done

for h in "${HOSTS[@]}"; do
    echo "Syncing ${h} UP"
    rsync -ral banned token limits "${h}":'/sf/config/db'
done