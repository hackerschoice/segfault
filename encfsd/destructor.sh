#! /bin/bash

# shellcheck disable=SC1091 # Do not follow
source /sf/bin/funcs.sh
source /sf/bin/funcs_redis.sh

# Defaults		
SF_TIMEOUT_WITH_SHELL=$((60 * 60 * 36))
SF_TIMEOUT_NO_SHELL=$((60 * 60 * 1))
SF_TIMEOUT_TOKEN_WITH_SHELL=$((60 * 60 * 24 * 7))
SF_TIMEOUT_TOKEN_NO_SHELL=$((60 * 60 * 36))
[[ -n $SF_DEBUG ]] && {
	SF_TIMEOUT_WITH_SHELL=60
	SF_TIMEOUT_NO_SHELL=15
	SF_TIMEOUT_TOKEN_WITH_SHELL=120
	SF_TIMEOUT_TOKEN_NO_SHELL=90
}

[[ ! -S /var/run/docker.sock ]] && ERREXIT 255 "Not found: /var/run/docker.sock"
source /funcs_destructor.sh || ERREXIT 255

export REDISCLI_AUTH="${SF_REDIS_AUTH}"

while :; do
	sleep 30
	source /config/etc/sf/timers.conf 2>/dev/null
	source /funcs_destructor.sh 2>/dev/null
	# shellcheck disable=2034
	NOW=$(date +%s)
	# Every 30 seconds check all container we are tracking (from encfsd)
	read -r -a containers < <(cd /sf/run/encfsd/user && echo lg-*)
	n=${#containers[@]}
	# Continue if no entry (it's lg-* itself)
	[[ $n -eq 1 ]] && [[ ! -f "/sf/run/encfsd/user/${containers[0]}" ]] && continue
	i=0
	# Get SEM
	redq BLPOP "sema:destructor" 15
	while [[ $i -lt $n ]]; do
		check_container "${containers[$i]}"
		((i++))
	done
	echo -e "DEL 'sema:destructor'\nRPUSH 'sema:destructor' 1" | red1 || LOG "destructor" "Could not release lock: sema:destructor"
done
