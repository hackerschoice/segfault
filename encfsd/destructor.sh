#! /bin/bash

source /sf/bin/funcs.sh

# [LID] <1=encfs> <1=Container>
# Either parameter can be "" to not stop encfs or lg-container 
stop_lg()
{
	local is_encfs
	local is_container
	local lid
	lid="$1"
	is_encfs="$2"
	is_container="$3"

	DEBUGF "ARG=$*"

	echo "[${lid}] Stopping"

	redis-cli -h 172.20.2.254 RPUSH portd:cmd "remport ${lid}" >/dev/null

	# Tear down container
	[[ ! -z $is_container ]] && docker stop "lg-$lid" &>/dev/nuill

	[[ ! -z $is_encfs ]] && { pkill -SIGTERM -f "^\[encfs-${lid}\]" || ERR "pkill [encfs-${lid}]"; }
}

is_recent()
{
	local pid
	local ts
	pid="$1"

	ts=$(stat -c %Y "/proc/${pid}")
	[[ -z $ts ]] && return 0
	# PID is younger than 20 seconds...
	[[ $((NOW - ts)) -lt 20 ]] && return 0

	return 255
}

# [lg-$LID]
# Check if lg- is running but EncFS died.
# Check if user logged out.
check_container()
{
	local c
	local lid
	local pid
	c="$1"
	lid="${c#lg-}"

	[[ ${#lid} -ne 10 ]] && return

	# Check if EncFS still exists.
	pid=$(pgrep -f "^\[encfs-${lid}\]" -a >/dev/null) || {
		ERR "[${lid}] EncFS died..."
		stop_lg "$lid" "" "lg"
		return
	}

	# Skip if this container only started recently.
	is_recent "${pid%% *}" && return

	# Check how many PIDS are running inside container:
	pids=($(docker top "$c" -eo pid)) || { DEBUGF "docker top '$c' failed"; return; }
	# DEBUGF "[${lid}] pids(${#pids[@]}) '${pids[*]}'"
	# 1. PS-Header (UID PID PPID C STIME TTY TIME)
	# 2. docker-init
	# 3. sleep infinity
	# 4. zsh user shell

	[[ "${#pids[@]}" -ge 4 ]] && return

	stop_lg "${lid}" "encfs" "lg"
}

# Check if EncFS is running but lg- died.
check_stale_mounts()
{
	local encs
	local IFS
	IFS=$'\n'

	encs=($(pgrep -f '^\[encfs-.*raw/user/user-' -a))

	i=0
	n=${#encs[@]}
	while [[ $i -lt $n ]]; do
		# 16249 [encfs-MzAZGViYTE] --standard --public -o nonempty -S /encfs/raw/user/user-MzAZGViYTE /encfs/sec/user-MzAZGViYTE -- -o noatime
		lid="${encs[$i]}"
		((i++))		
		# There is a race condition here:
		# 1. encfs starts
		# 2. Container is not yet started
		# 3. encfs is killed here.
		# Give EncFS at least 20 seconds to live and time for lg-container to start.
		is_recent "${lid%% *}" && continue

		lid="${lid%%\]*}"
		lid="${lid#*\[encfs-}"
		[[ ${#lid} -ne 10 ]] && continue
		docker container inspect "lg-${lid}" -f '{{.State.Status}}' &>/dev/null && continue
		ERR "[${lid}] Unmounting stale EncFS (lg-${lid} died)."
	
		stop_lg "${lid}" "encfs" ""
	done
}

[[ ! -S /var/run/docker.sock ]] && ERREXIT 255 "Not found: /var/run/docker.sock"
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

while :; do
	sleep 10
	NOW=$(date +%s)
	# Every 30 seconds check all running lg-containers if they need killing.
	# docker ps -f "name=^lg" --format "{{.ID}} {{.Names}}"
	containers=($(docker ps -f "name=^lg-" --format "{{.Names}}"))
	[[ -z $containers ]] && continue
	i=0
	n=${#containers[@]}
	while [[ $i -lt $n ]]; do
		check_container "${containers[$i]}"
		((i++))
	done

	check_stale_mounts
done
