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
	lid="$1"
	is_encfs="$2"
	is_container="$3"

	LOG "$lid" "Stopping. $4"

	red RPUSH portd:cmd "remport ${lid}" >/dev/null

	# Tear down container
	[[ -n $is_container ]] && docker stop "lg-$lid" &>/dev/nuill

	# Odd: On cgroup2 the command 'docker top lg-*' shows that encfs is running
	# inside the container even that we never moved it into the container's
	# Process Namespace. EncFS will also die when the lg- is shut down.
	# This is only neede for cgroup1:
	[[ -n $is_encfs ]] && pkill -SIGTERM -f "^\[encfs-${lid}\]" 2>/dev/null
}

# Return 0 if container started just recently.
# - It's recent
# - It no longer exists.
is_recent()
{
	local pid
	local ts
	pid="$1"

	[[ -z "${pid}" ]] && { WARN "pid='${pid}' is empty"; return 0; }

	ts=$(stat -c %Y "/proc/${pid}" 2>/dev/null) || return 0
	# Can happen that container quit just now. Ignore if failed.
	[[ -z $ts ]] && return 0
	# PID is younger than 20 seconds...
	[[ $((NOW - ts)) -lt 20 ]] && return 0

	return 255
}

# [lg-$LID]
# Check if lg- is running and
# 1. EncFS died
# 2. Container should be stopped (stale, idle)
check_container()
{
	local c
	local lid
	local pid
	local i
	local IFS
	local fn
	local comm
	local ts
	IFS=$'\n'

	c="$1"
	lid="${c#lg-}"

	[[ ${#lid} -ne 10 ]] && return

	# Check if EncFS is still running.
	pid=$(pgrep -f "^\[encfs-${lid}\]" -a 2>/dev/null) || {
		stop_lg "$lid" "" "lg" "${CR}EncFS died...${CN}"
		return
	}

	# Skip if this container only started recently (EncFS not up yet).
	is_recent "${pid%% *}" && return

	fn="/config/db/user/lg-${lid}/ts_logout"
	[[ -f "$fn" ]] && ts=$(stat -c %Y "$fn") 
	[[ -z $ts ]] && ts=0

	# Check if there is still a shell running inside the container:
	IFS=""
	comm=$(docker top "$c" -eo pid,comm 2>/dev/null | tail +2 | awk '{print $2;}') || { ERR "docker top '$c' failed"; return; }
	echo "$comm" | grep -m1 -E '(^zsh$|^bash$|^sh$)' >/dev/null && {
		# HERE: User still has shell running
		[[ -f "/config/db/user/lg-${lid}/is_logged_in" ]] && return
		[[ $((NOW - ts)) -lt ${SF_TIMEOUT_WITH_SHELL} ]] && return
		# HERE: Not logged in. logged out more than 1 week ago.

		stop_lg "${lid}" "encfs" "lg" "Not logged in for ${SF_TIMEOUT_WITH_SHELL}sec (shell running)."
		return
	}
	# HERE: No shell running

	# Skip if only recently logged out.
	[[ $((NOW - ts)) -lt 60 ]] && return # Recently logged out.

	# Filter out stale processes
	echo "$comm" | grep -m1 -v -E '(^docker-init$|^sleep$|^encfs$|^gpg-agent$)' >/dev/null || {
		# HERE: Nothing running but stale processes
		stop_lg "${lid}" "encfs" "lg" "No processes running."
		return
	}
	# HERE: Something running (but no shell, and no known processes)

	# Check if ts_logout is valid
	# [[ $ts -eq 0 ]] && ERR "[${CDM}${lid}${CN}] ts_logout missing?"

	[[ $((NOW - ts)) -ge ${SF_TIMEOUT_NO_SHELL} ]] && {
		# User logged out 1.5 days ago. No shell. No known processes.
		stop_lg "${lid}" "encfs" "lg" "Not logged in for ${SF_TIMEOUT_NO_SHELL}sec (no shell running)."
		return
	}
}

# Check if EncFS is running but lg- died.
# check_stale_mounts()
# {
# 	local encs
# 	local IFS
# 	IFS=$'\n'

# 	encs=($(pgrep -f '^\[encfs-.*raw/user/user-' -a))

# 	i=0
# 	n=${#encs[@]}
# 	while [[ $i -lt $n ]]; do
# 		# 16249 [encfs-MzAZGViYTE] --standard --public -o nonempty -S /encfs/raw/user/user-MzAZGViYTE /encfs/sec/user-MzAZGViYTE -- -o noatime
# 		lid="${encs[$i]}"
# 		((i++))		
# 		# There is a race condition here:
# 		# 1. encfs starts
# 		# 2. Container is not yet started
# 		# 3. encfs is killed here.
# 		# Give EncFS at least 20 seconds to live and time for lg-container to start.
# 		is_recent "${lid%% *}" && continue

# 		lid="${lid%%\]*}"
# 		lid="${lid#*\[encfs-}"
# 		[[ ${#lid} -ne 10 ]] && continue
# 		docker container inspect "lg-${lid}" -f '{{.State.Status}}' &>/dev/null && continue
# 		ERR "[${CDM}${lid}${CN}] Unmounting stale EncFS (lg-${lid} died)."
	
# 		stop_lg "${lid}" "encfs" "" "Container died."
# 	done
# }

[[ ! -S /var/run/docker.sock ]] && ERREXIT 255 "Not found: /var/run/docker.sock"
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

while :; do
	sleep 25 # Check every 30 seconds. wait 25 here and 5 below.
	NOW=$(date +%s)
	# Every 30 seconds check all running lg-containers if they need killing.
	# docker ps -f "name=^lg" --format "{{.ID}} {{.Names}}"
	containers=($(docker ps -f "name=^lg-" --format "{{.Names}}"))
	n=${#containers[@]}
	i=0
	while [[ $i -lt $n ]]; do
		check_container "${containers[$i]}"
		((i++))
	done
	# We must give EncFS time to die by SIGTERM or otherwise check_stale_mounts
	# still sees the encfs and tries to kill it again (which would yield an ugly
	# warning).
	sleep 5

	# 2023-02-11: This is no longer needed on cgroup2 systems where docker
	# kills all process in the namespace _and_ and processes in the same cgroup2.
	# check_stale_mounts
done
