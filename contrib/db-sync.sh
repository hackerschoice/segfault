#! /usr/bin/env bash

## In the format of:
# HOSTS+=("adm")
# HOSTS+=("lgm")

do_down() {
	local h
	local i
	i=${#HOSTS[@]}
	while [[ $i -gt 0 ]]; do
	    ((i--))
	    h="${HOSTS[$i]}"
    	    [[ -n "$1" ]] && [[ "$1" != "$h" ]] && continue
	    echo "#${i} Syncing ${h} DOWN"
 	   rsync -ral "${h}":/sf/config/db/banned .
	# "${h}":/sf/config/db/token "${h}":/sf/config/db/limits .
	done
}

source .env_hosts || exit

IS_DOWN=1
IS_UP=1
[[ "${1,,}" == "up" ]] && unset IS_DOWN
[[ "${1,,}" == "down" ]] && unset IS_UP
shift 1

echo "PRIVATE, LIMITS and TOKEN are now taken from SYSCOPS workstation. ADM is no longer the master"
# SYNC private/ is DANGEROUS because those files are SOUCED by
# all other systems. Instead we keep the files on a SYSCOP workstation
# and only PUSH from workstation to servers. Dont use the below:
#h=adm
#rsync -ral "${h}":/sf/config/db/private .

# Reverse order so that first in HOSTS has master priority
#rm -rf banner
[[ -n "$IS_DOWN" ]] && {
	do_down "$@"
}

i=0
for h in "${HOSTS[@]}"; do
    [[ -n "$1" ]] && [[ "$1" != "$h" ]] && continue
    echo "#$i Syncing ${h} UP"
    rsync -ral --delete  banned private token limits "${h}":'/sf/config/db'
    ((i++))
done
