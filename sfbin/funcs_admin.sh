#! /bin/bash

[[ $(basename -- "$0") == "funcs_admin.sh" ]] && { echo "ERROR. Use \`source $0\` instead."; exit 1; }
_basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd)"
# shellcheck disable=SC1091 # Do not follow
# source "${_basedir}/funcs.sh"
unset _basedir

_cgbdir="/sys/fs/cgroup"
[[ -d /sys/fs/cgroup/unified/ ]] && _cgbdir="/sys/fs/cgroup/unified"
_self_for_guest_dir="/dev/shm/sf-u1000/self-for-guest"
[[ -d /dev/shm/sf/self-for-guest ]] && _self_for_guest_dir="/dev/shm/sf/self-for-guest"
_sf_basedir="/sf"

_sf_deinit()
{
	unset CY CG CR CC CB CF CN CDR CDG CDY CDB CDM CDC CUL
}

_sf_init()
{
	[[ ! -t 1 ]] && return

	CY="\e[1;33m" # yellow
	CG="\e[1;32m" # green
	CR="\e[1;31m" # red
	CC="\e[1;36m" # cyan
	# CM="\e[1;35m" # magenta
	# CW="\e[1;37m" # white
	CB="\e[1;34m" # blue
	CF="\e[2m"    # faint
	CN="\e[0m"    # none
	# CBG="\e[42;1m" # Background Green
	# night-mode
	CDR="\e[0;31m" # red
	CDG="\e[0;32m" # green
	CDY="\e[0;33m" # yellow
	CDB="\e[0;34m" # blue
	CDM="\e[0;35m" # magenta
	CDC="\e[0;36m" # cyan
	CUL="\e[4m"
}

_sf_usage()
{
	[[ ! -t 1 ]] && return
	_sf_init

	echo -e "${CDC}container_df <regex>${CN}                   # eg \`container_df ^lg\`"
	echo -e "${CDC}lgwall [lg-LID] <message>${CN}              # eg \`lgwall lg-NGVlMTNmMj "'"Get\\nLost\\n"`'
	echo -e "${CDC}lgstop [lg-LID] <message>${CN}              # eg \`lgstop lg-NmEwNWJkMW "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lgban  [lg-LID] <message>${CN}              # Stop & Ban IP address, eg \`lgban lg-NmEwNWJkMW "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lgps [ps regex] <stop> <message>${CN}       # eg \`lgps 'dd if=/dev/zero' stop "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lg_cleaner [max_pid_count=3] <stop>${CN}    # eg \`lg_cleaner 3 stop\` or \`lg_cleaner 0\`"
	echo -e "${CDC}docker_clean${CN}                           # Delete all containers & images"
	echo -e "${CDC}lgsh [lg-LID]${CN}                          # Enter bash [FOR TESTING]"
	echo -e "${CDC}lghst [regex]${CN}                          # grep in zsh_history [FOR TESTING]"
	echo -e "${CDC}lgcpu${CN}                                  # Sorted list of CPU usage"
	echo -e "${CDC}lgmem${CN}                                  # Sorted list of MEM usage"
	echo -e "${CDC}lgio${CN}                                   # Sorted list of Network OUT usage"
	echo -e "${CDC}lgbio${CN}                                  # Sorted list of BlockIO usage"
	echo -e "${CDC}sftop${CN}"
	echo -e "${CDC}lghelp${CN}                                 # THIS HELP"

	_sf_deinit
}

lghelp() { _sf_usage; }

# Show overlay2 usage by container REGEX match.
# container_df ^lg
container_df()
{
	for container in $(docker ps --all --quiet --format '{{ .Names }}'); do
		[[ -n $1 ]] && [[ ! $container =~ ${1:?} ]] && continue
		mdir=$(docker inspect "$container" --format '{{.GraphDriver.Data.UpperDir }}')
		size="$(du -sk "$mdir" | cut -f1)                        "
		cn="${container}                                         "
		echo "${size:0:10} ${cn:0:20} $(echo "$mdir" | grep -Po '^.+?(?=/diff)'  )" 
	done        
}

# Send a message to all PTS of a specific container
# Example: lgwall lg-NGVlMTNmMj "Get \nlost\n"
# [lg-LID] [message]
lgwall()
{
	# This 
	local pid
	local cid
	[[ -z $2 ]] && { echo >&2 "lgwall LID [message]"; return; }
	cid=$(docker inspect --format='{{.Id}}' "$1") || return
	pid=$(<"/var/run/containerd/io.containerd.runtime.v2.task/moby/${cid}/init.pid") || return
	for fn in "/proc/${pid}/root/dev/pts"/*; do
		[[ "${fn##*/}" =~ [^0-9] ]] && continue
		[[ ! -c "$fn" ]] && continue
		hex=$(stat -c %t "$fn")
		maj="$((16#$hex))"
		[[ "$maj" -ge 136 ]] && [[ "$maj" -le 143 ]] && echo -e "\n@@@@@ SYSTEM MESSAGE\n${2}\n@@@@@" >>"${fn}"
	done
}

# <lg-LID> <MESSAGE>
lgstop()
{
	[[ -n $2 ]] && { lgwall "${1}" "$2"; }
	docker stop "${1}"
}

lgban()
{
	local fn
	local ip
	fn="${_self_for_guest_dir}/${1}/ip"
	[[ -f "$fn" ]] && {
		ip=$(<"$fn")
		fn="/sf/config/db/banned/ip-${ip:0:18}"
		[[ ! -e "$fn" ]] && touch "$fn"
		echo "Banned: $ip"
	}

	lgstop "$@"	
}

_sfcg_forall()
{
	local IFS
	local arr
	local l
	local a
	local ts
	local fn
	IFS=$'\n' arr=($(docker ps --format "{{.Names}}"  --filter 'name=^lg-'))

	for l in "${arr[@]}"; do
		ts=2147483647
		fn="${_sf_basedir}/config/db/user/${l}/created.txt"
		[[ -f "$fn" ]] && ts=$(date +%s -u -r "$fn")
		a+=("$ts $l")
	done
	echo "${a[*]}" | sort -n | cut -f2 -d" "
}

# [LG-LID]
_sfcg_psarr()
{
	local found
	local lglid
	local match
	local str
	local IFS
	lglid="$1"
	match="$2"
	found=0
	[[ -z $match ]] && found=1 # empty string => Show all

	IFS= str=$(docker top "${lglid}" -e -o pid,bsdtime,rss,start_time,comm,cmd)
	[[ -n $str ]] && [[ -n $match ]] && [[ "$str" =~ $match ]] && found=1

	echo "$str"
	return $found
}

_sfcfg_printlg()
{
		local lglid
		local geoip
		local ip
		local fn
		local hn
		lglid=$1

		[[ -f "${_self_for_guest_dir}/${lglid}/ip" ]] && ip=$(<"${_self_for_guest_dir}/${lglid}/ip")
		ip="${ip}                      "
		ip="${ip:0:16}"
		[[ -f "${_sf_basedir}/config/db/user/${lglid}/hostname" ]] && hn=$(<"${_sf_basedir}/config/db/user/${lglid}/hostname")
		hn="${hn}                      "
		hn="${hn:0:16}"
		[[ -f "${_self_for_guest_dir}/${lglid}/geoip" ]] && geoip=" $(<"${_self_for_guest_dir}/${lglid}/geoip")"
		fn="${_sf_basedir}/config/db/user/${lglid}/created.txt"
		[[ -f "${fn}" ]] && t_created=$(date '+%F %T' -u -r "${fn}")
		echo -e "${CDY}====> ${CDC}${t_created:-????-??-?? ??-??-??} ${CDM}${lglid} ${CDB}${hn} ${CG}${ip} ${CDG}${geoip}${CN}"
}

lgls()
{
    local IFS

	_sf_init
    IFS=$'\n' arr=($(_sfcg_forall))
	for lglid in "${arr[@]}"; do
        _sfcfg_printlg "$lglid"
	done

	_sf_deinit
}

# Show all LID where REGEX matches a process+arguments and optionally stop
# the container.
# Example: plgtop urandom
# Example: plgtop urandom stop
# [<REGEX>] <stop> <stop-message-to-user>
lgps()
{
	local lglid
	local match
	local stoparr
	local msg
	local is_stop
	match=$1
	msg="$3"

	[[ "$2" == "stop" ]] && is_stop=1

	_sf_init
	stoparr=()
	IFS=$'\n' arr=($(_sfcg_forall))
	for lglid in "${arr[@]}"; do
		IFS= str=$(_sfcg_psarr "$lglid" "$match") && continue

		_sfcfg_printlg "$lglid"
		if [[ -z $match ]]; then
			echo "$str"
		else
			echo "$str" | grep -E "${match:?}"'|$'
		fi
		[[ -n $msg ]] && lgwall "${lglid}" "$msg"
		[[ -n $is_stop ]] && stoparr+=("${lglid}")
	done
	[[ ${#stoparr[@]} -gt 0 ]] && docker stop "${stoparr[@]}"

	_sf_deinit
}

#plgtop "/bin/bash /everyone" stop                # Example
#plgtop "dd if=/dev/zero of=/dev/null" stop
#plgtop "bzip2 -9" stop

# Stop all container that have no SSH connection and only 3 processes (init, sleep, zsh)
# NOTE: This should not happen any longer since a bug in docker-sigproxy got fixed.
# Example: lg_cleaner
# Example: lg_cleaner stop
lg_cleaner()
{
	local is_stop
	local max
	local IFS
	max="$1"
	is_stop="$2"
	[[ -z $max ]] && max=3
	IFS=$'\n'
	real=($(pgrep docker-exec-sig -a | awk '{print $5;}'))
	all=($(docker ps -f name=^lg- --format "table {{.Names}}"))
	for x in "${all[@]}"; do
		[[ ! $x =~ ^lg- ]] && continue
		[[ "${real[*]}" =~ $x ]] && continue
		# check how many processes are running:
		arr=($(docker top "${x}" -o pid ))
		n=${#arr[@]}
		[[ ! $n -gt 1 ]] && n=1
		((n--))
		[[ $max -gt 0 ]] && [[ $n -gt $max ]] && continue
		echo "===========> $x n=$n"
		docker top "$x"
		[[ -n $is_stop ]] && docker stop -t1 "$x"
	done
}

# Delete all images
docker_clean()
{
	# shellcheck disable=SC2046
	docker rm $(docker ps -a -q)
	# shellcheck disable=SC2046
	docker rmi $(docker images -q)
}

_sfmax()
{
	docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | grep -E '(^lg-|^NAME)' | sort -k "$1" -h
}

lgsh() { docker exec -w/root -u0 -e HISTFILE=/dev/null -it "$1" bash -c 'exec -a [cached] bash'; }

_grephst()
{
	local fn
	fn=$2

	[[ ! -e "$fn" ]] && return
	grep -E "$1" "${fn}" || return
	echo "=== ${fn}"
}
lghst() {
	cd /dev/shm/sf-u1000/encfs-sec || return
	for d in lg-*; do
		_grephst "$1" "${d}/root/.zsh_history"
	done
}

lgcpu() { _sfmax 3; }
lgmem() { _sfmax 4; }
lgio() { _sfmax 7; }
lgbio() { echo "========= INPUT"; _sfmax 8; echo "=========== OUTPUT"; _sfmax 10; }


sftop()
{
	docker run --rm -ti --name=ctop --volume /var/run/docker.sock:/var/run/docker.sock:ro   quay.io/vektorlab/ctop:latest
}

_sf_usage
