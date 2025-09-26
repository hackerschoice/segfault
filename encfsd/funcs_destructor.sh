
# [LID] <1=encfs> <1=Container> <message>
# Either parameter can be "" to not stop encfs or lg-container 
stop_lg()
{
	local is_encfs
	local lid
	local ts_born
	local msg="$5"
	lid="$1"
	ts_born="$2"
	is_encfs="$3"

	LOG "$lid" "Stopping [$((NOW - ts_born)) sec]. ${msg}"

	# Remove reverse port.
	red RPUSH portd:cmd "remport ${lid}" >/dev/null

	# Teardown LG
	docker exec sf-master /teardown-lg.sh "${lid}"

	# Remove files
	rm -f 	"/sf/run/encfsd/user/lg-${lid}"\
			"/sf/run/ips/lg-${lid}.ip"
	rm -rf 	"/config/self-for-guest/lg-${lid}"\
			"/sf/run/users/lg-${lid}"

	# Stop container
	docker stop "lg-$lid" &>/dev/null

	# Odd: On cgroup2 the command 'docker top lg-*' shows that encfs is running
	# inside the container even that we never moved it into the container's
	# Process Namespace. EncFS will also die when the lg- is shut down.
	# This is only needed for cgroup1:
	[[ -n $is_encfs ]] && {
		pkill -SIGTERM -f "^\[encfs-${lid}\]" 2>/dev/null
		# Give kernel time to unmount mountpoint
		sleep 1
	}
	# Do not use 'rm -rf' here as this might still be a mounted drive
	# when encfsd is not killed fast enough (failing to delete is acceptable).
	rm -f "/encfs/sec/lg-${lid}/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"
	rmdir "/encfs/sec/lg-${lid}"
}

try_syscop_msg() {
	local lid="$1"
	echo -en "\
🤷‍♂️ ${CDM}Your server shut down automatically because you did not log in for $(( (NOW - ts_logout) / 60 / 60 )) h.
🫵 Please type ${CDC}halt${CDM} to stop your server or...
❤️  ...get a ${CM}TOKEN${CDM} to stop this message: ${CUL}${CB}https://thc.org/sf/token${CN}${CDM}

🌈 ${CW}Yours sincerely, The SysCops 😘 ${CN}
">"/config/db/user/lg-${lid:?}/syscop-msg.txt"
}

# [lg-$LID]
# Check if lg- is running and
# 1. EncFS died
# 2. Container should be stopped (stale, idle)
check_container()
{
	local c
	local lid
	local IFS=$'\n'
	local fn
	local comm
	local ts_logout
	local ts_born
	local to_with_shell=$SF_TIMEOUT_WITH_SHELL
	local to_no_shell=$SF_TIMEOUT_NO_SHELL
	local is_token

	c="$1"
	lid="${c#lg-}"

	[[ ${#lid} -ne 10 ]] && return

	ts_born=$(stat -c %Y "/sf/run/encfsd/user/lg-${lid}") || { ERR "[${CDM}${lid}${CN}] run/encfsd/user/lg-* missing?"; return; }
	# Skip if EncFS only started recently (zsh not yet started).
	[[ $((NOW - ts_born)) -lt 20 ]] && return 0

	# Check if EncFS is still running.
	pgrep -f "^\[encfs-${lid}\]" &>/dev/null || {
		# NOTE: On CGROUPv2 the encfs dies when the lg container stops (user called 'halt' or 'docker stop')
		stop_lg "$lid" "${ts_born}" "" "EncFS died..."
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
		set +o pipefail
		stop_lg "${lid}" "${ts_born}" "encfs" "LG no longer running."
		return
	}

	# Load timers
	[[ -e "/config/db/user/lg-${lid}/token" ]] && {
		to_with_shell=$SF_TIMEOUT_TOKEN_WITH_SHELL
		to_no_shell=$SF_TIMEOUT_TOKEN_NO_SHELL
		is_token=1
	}
	set +o pipefail
	# Note: We must set 'set +o pipefail' (e.g. fail only if last command errors). Otherwise the rare
	# condition can happen where grep exits (first match found) but 'echo' is still writing. Then echo
	# will receive a SIGPIPE and exit with 141 and the entire pipe will fail.
	
	# [[ -f "/config/db/user/lg-${lid}/is_logged_in" ]] && return
	# FIXME: many stale is_logged_in exists without ssh connected ;/

	# HERE: LG & EncFS are running.
	echo "$comm" | grep -m1 -E '(^zsh$|^bash$|^sh$|^sftp-server$)' >/dev/null && {
		# HERE: User still has shell running
		[[ -f "/config/db/user/lg-${lid}/is_logged_in" ]] && return
		[[ $((NOW - ts_logout)) -lt ${to_with_shell} ]] && return
		# HERE: Not logged in. logged out more than 1 week ago.
		stop_lg "${lid}" "${ts_born}" "encfs" "Not logged in for $((NOW - ts_logout))sec (shell running)." || return
		[[ -z $is_token ]] && try_syscop_msg "$lid"

		return
	}
	# HERE: No shell running, ts_logout=0 if never logged out

	# Skip if only recently logged out.
	[[ $((NOW - ts_logout)) -lt 60 ]] && return # Recently logged out.

	# Filter out stale processes
	echo "$comm" | grep -m1 -v -E '(^docker-init$|^sleep$|^encfs$|^gpg-agent$)' >/dev/null || {
		# HERE: Nothing running but stale processes
		stop_lg "${lid}" "${ts_born}" "encfs" "No processes running."
		return
	}
	# HERE: Something running (but no shell, and no known processes)

	[[ $((NOW - ts_logout)) -ge ${to_no_shell} ]] && {
		# User logged out 1.5 days ago. No shell. No known processes.

		stop_lg "${lid}" "${ts_born}" "encfs" "Not logged in for ${to_no_shell}sec (no shell running)." || return
		[[ -z $is_token ]] && try_syscop_msg "$lid"

		return
	}

	# HERE: No shell. No known processes. Less than 1.5 days ago.
}
