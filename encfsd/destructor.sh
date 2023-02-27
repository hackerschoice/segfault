#! /bin/bash

# shellcheck disable=SC1091 # Do not follow
source /sf/bin/funcs.sh
source /sf/bin/funcs_redis.sh
		
SF_TIMEOUT_WITH_SHELL=604800
SF_TIMEOUT_NO_SHELL=129600
[[ -n $SF_DEBUG ]] && {
	SF_TIMEOUT_WITH_SHELL=180
	SF_TIMEOUT_NO_SHELL=120
}

# [LID] <1=encfs> <1=Container> <message>
# Either parameter can be "" to not stop encfs or lg-container 
stop_lg()
{
	local is_encfs
	local is_container
	local lid
	local ts_born
	lid="$1"
	ts_born="$2"
	is_encfs="$3"
	is_container="$4"

	LOG "$lid" "Stopping [$((NOW - ts_born)) sec]. $5"

	red RPUSH portd:cmd "remport ${lid}" >/dev/null
	rm -f "/sf/run/encfsd/user/lg-${lid}"

	# Tear down container
	[[ -n $is_container ]] && docker stop "lg-$lid" &>/dev/nuill

	# Odd: On cgroup2 the command 'docker top lg-*' shows that encfs is running
	# inside the container even that we never moved it into the container's
	# Process Namespace. EncFS will also die when the lg- is shut down.
	# This is only neede for cgroup1:
	[[ -n $is_encfs ]] && pkill -SIGTERM -f "^\[encfs-${lid}\]" 2>/dev/null
}

# [lg-$LID]
# Check if lg- is running and
# 1. EncFS died
# 2. Container should be stopped (stale, idle)
check_container()
{
	local c
	local lid
	local i
	local IFS
	local fn
	local comm
	local ts_logout
	local ts_born
	IFS=$'\n'

	c="$1"
	lid="${c#lg-}"

	[[ ${#lid} -ne 10 ]] && return

	ts_born=$(stat -c %Y "/sf/run/encfsd/user/lg-${lid}") || { ERR "[${CDM}${lid}${CN}] run/encfsd/user/lg-* missing?"; return; }
	# Skip if EncFS only started recently (zsh not yet started).
	[[ $((NOW - ts_born)) -lt 20 ]] && return 0

	# Check if EncFS is still running.
	pgrep -f "^\[encfs-${lid}\]" &>/dev/null || {
		# NOTE: On CGROUPv2 the encfs dies when the lg container stops (user called 'halt' or 'docker stop')
		stop_lg "$lid" "${ts_born}" "" "lg" "EncFS died..."
		return
	}

	# ts_logout may not exist (stale)
	ts_logout=0
	fn="/config/db/user/lg-${lid}/ts_logout"
	[[ -f "$fn" ]] && ts_logout=$(stat -c %Y "$fn") 

	# Check if there is still a shell running inside the container:
	IFS=""
	set -o pipefail
	comm=$(docker top "lg-${lid}" -eo pid,comm 2>/dev/null | tail +2 | awk '{print $2;}') || {
		# HERE: lg died or top failed.
		stop_lg "${lid}" "${ts_born}" "encfs" "lg" "LG no longer running."
		return
	}

	# [[ -f "/config/db/user/lg-${lid}/is_logged_in" ]] && return
	# FIXME: many stale is_logged_in exists without ssh connected ;/

	# HERE: LG & EncFS are running.
	echo "$comm" | grep -m1 -E '(^zsh$|^bash$|^sh$|^sftp-server$)' >/dev/null && {
		# HERE: User still has shell running
		[[ -f "/config/db/user/lg-${lid}/is_logged_in" ]] && return
		[[ $((NOW - ts_logout)) -lt ${SF_TIMEOUT_WITH_SHELL} ]] && return
		# HERE: Not logged in. logged out more than 1 week ago.

		stop_lg "${lid}" "${ts_born}" "encfs" "lg" "Not logged in for $((NOW - ts_logout))sec (shell running)."
		echo "$comm" >"/dev/shm/lg-${lid}.ps" # DEBUG
		return
	}
	# HERE: No shell running, ts_logout=0 if never logged out

	# Skip if only recently logged out.
	[[ $((NOW - ts_logout)) -lt 60 ]] && return # Recently logged out.

	# Filter out stale processes
	echo "$comm" | grep -m1 -v -E '(^docker-init$|^sleep$|^encfs$|^gpg-agent$)' >/dev/null || {
		# HERE: Nothing running but stale processes
		stop_lg "${lid}" "${ts_born}" "encfs" "lg" "No processes running."
		echo "$comm" >"/dev/shm/lg-${lid}.ps" # DEBUG
		return
	}
	# HERE: Something running (but no shell, and no known processes)

	[[ $((NOW - ts_logout)) -ge ${SF_TIMEOUT_NO_SHELL} ]] && {
		# User logged out 1.5 days ago. No shell. No known processes.
		stop_lg "${lid}" "${ts_born}" "encfs" "lg" "Not logged in for ${SF_TIMEOUT_NO_SHELL}sec (no shell running)."
		echo "$comm" >"/dev/shm/lg-${lid}.ps" # DEBUG
		return
	}

	# HERE: No shell. No known processes. Less than 1.5 days ago.
}

[[ ! -S /var/run/docker.sock ]] && ERREXIT 255 "Not found: /var/run/docker.sock"
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

while :; do
	sleep 30
	NOW=$(date +%s)
	# Every 30 seconds check all container we are tracking (from encfsd)
	containers=($(cd /sf/run/encfsd/user && echo lg-*))
	n=${#containers[@]}
	# Continue if no entry (it's lg-* itself)
	[[ $n -eq 1 ]] && [[ ! -f "/sf/run/encfsd/user/${containers[0]}" ]] && continue
	i=0
	while [[ $i -lt $n ]]; do
		check_container "${containers[$i]}"
		((i++))
	done
done
