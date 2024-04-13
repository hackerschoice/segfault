#! /usr/bin/env bash

## In the format of:
# HOSTS+=("adm")
# HOSTS+=("lgm")

source .env_hosts || exit

echo "PRIVATE, LIMITS and TOKEN are now taken from SYSCOPS workstation. ADM is no longer the master"
# SYNC private/ is DANGEROUS because those files are SOUCED by
# all other systems. Instead we keep the files on a SYSCOP workstation
# and only PUSH from workstation to servers. Dont use the below:
#h=adm
#rsync -ral "${h}":/sf/config/db/private .

# Reverse order so that first in HOSTS has master priority
#rm -rf banner
i=${#HOSTS[@]}
while [[ $i -gt 0 ]]; do
    ((i--))
    h="${HOSTS[$i]}"
    echo "#${i} Syncing ${h} DOWN"
    rsync -ral "${h}":/sf/config/db/banned .
# "${h}":/sf/config/db/token "${h}":/sf/config/db/limits .
done

echo "==[DOWN done. Press Enter to start UP]=================================================="
read 
i=0
for h in "${HOSTS[@]}"; do
    echo "#$i Syncing ${h} UP"
    rsync -ral --delete  banned private token limits "${h}":'/sf/config/db'
    ((i++))
done
