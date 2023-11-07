#! /usr/bin/env bash

## In the format of:
# HOSTS+=("adm")
# HOSTS+=("lgm")

source .env_hosts || exit

# Reverse order so that first in HOSTS has master priority
i=${#HOSTS[@]}
while [[ $i -gt 0 ]]; do
    ((i--))
    h="${HOSTS[$i]}"
    echo "#${i} Syncing ${h} DOWN"
    rsync -ral "${h}":/sf/config/db/banned "${h}":/sf/config/db/token "${h}":/sf/config/db/limits .
done

echo "==[DOWN done. Press Enter to start UP]=================================================="
read 
i=0
for h in "${HOSTS[@]}"; do
    echo "#$i Syncing ${h} UP"
    rsync -ral banned token limits "${h}":'/sf/config/db'
    ((i++))
done
