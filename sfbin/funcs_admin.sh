#! /bin/bash

[[ $(basename -- "$0") == "funcs_admin.sh" ]] && { echo "ERROR. Use \`source $0\` instead."; exit 1; }
_basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd)"
source "${_basedir}/funcs.sh"
unset _basedir

_cgbdir="/sys/fs/cgroup"
[[ -d /sys/fs/cgroup/unified/ ]] && _cgbdir="/sys/fs/cgroup/unified"
_self_for_guest_dir="/dev/shm/sf-u1000/self-for-guest"
[[ -d /dev/shm/sf/self-for-guest ]] && _self_for_guest_dir="/dev/shm/sf/self-for-guest"

# Show overlay2 usage by container REGEX match.
# container_df ^lg
container_df()
{
        for container in $(docker ps --all --quiet --format '{{ .Names }}'); do
		[[ -n $1 ]] && [[ ! $container =~ ${1:?} ]] && continue
		mdir="$(docker inspect $container --format '{{.GraphDriver.Data.UpperDir }}')" 
		size="$(du -sk "$mdir" | cut -f1)                        "
		cn="${container}                                         "
		echo "${size:0:10} ${cn:0:20} $(echo "$mdir" | grep -Po '^.+?(?=/diff)'  )" 
	done        
}
echo -e "${CDC}container_df <regex>${CN}                   # eg \`container_df ^lg\`"

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
echo -e "${CDC}lgwall [lg-LID] <message>${CN}              # eg \`lgwall lg-NGVlMTNmMj "'"Get\\nLost\\n"`'

# <lg-LID> <MESSAGE>
lgstop()
{
	[[ -n $2 ]] && { lgwall "${1}" "$2"; }
	docker stop "${1}"
}
echo -e "${CDC}lgstop [lg-LID] <message>${CN}              # eg \`lgstop lg-NmEwNWJkMW "'"***ABUSE***\\nContact Sysop"`'

_sfcg_forall()
{
	docker ps --format "{{.Names}}"  --filter 'name=^lg-'
}

# [LG-LID]
_sfcg_psarr()
{
	local found
	local lglid
	local match
	local str
	lglid="$1"
	match="$2"
	found=0
	[[ -z $match ]] && found=1 # empty string => Show all

	IFS= str=$(docker top "${lglid}" -e -o pid,bsdtime,rss,start_time,comm,cmd)
	[[ -n $str ]] && [[ -n $match ]] && [[ "$str" =~ $match ]] && found=1

	echo "$str"
	# IFS=$'\n' arr=("$str")
	# printf "%s\n" "${arr[@]}"
	return $found
}

# Show all LID where REGEX matches a process+arguments and optionally stop
# the container.
# Example: plgtop urandom
# Example: plgtop urandom stop
# [<REGEX>] <stop> <stop-message-to-user>
lgps()
{
	local i
	local ip
	local geoip
	local lglid
	local match
	local stoparr
	local stopmsg
	match=$1
	stopmsg="$3"

	stoparr=()
	i=0
	IFS=$'\n' arr=($(_sfcg_forall))
	while [[ $i -lt ${#arr[@]} ]]; do
		lglid=${arr[$i]}
		((i++))
		IFS= str=$(_sfcg_psarr "$lglid" "$match")
		[[ $? -eq 0 ]] && continue

		[[ -f "${_self_for_guest_dir}/${lglid}/ip" ]] && ip=$(<"${_self_for_guest_dir}/${lglid}/ip")
		[[ -f "${_self_for_guest_dir}/${lglid}/geoip" ]] && geoip=" $(<"${_self_for_guest_dir}/${lglid}/geoip")"
		echo -e "${CDY}====> ${CB}${lglid} ${CG}${ip} ${CDG}${geoip} ${CN}"
		if [[ -z $match ]]; then
			echo "$str"
		else
			echo "$str" | grep -E "${match:?}"'|$'
		fi
		[[ -n $2 ]] && {
			[[ -n $stopmsg ]] && lgwall "${lglid}" "$stopmsg"
			stoparr+=("${lglid}")
		}
	done
	[[ ${#stoparr[@]} -gt 0 ]] && docker stop "${stoparr[@]}"
}
echo -e "${CDC}lgps [ps regex] <stop> <message>${CN}       # eg \`lgps 'dd if=/dev/zero' stop "'"***ABUSE***\\nContact Sysop"`'

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
	max="$1"
	is_stop="$2"
	[[ -z $max ]] && max=3
	IFS=$'\n'
	real=($(ps alxww | grep -v grep | grep -F " docker-exec-sigproxy exec -i" | awk '{print $16;}'))
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
echo -e "${CDC}lg_cleaner [max_pid_count=3] <stop>${CN}    # eg \`lg_cleaner 3 stop\` or \`lg_cleaner 0\`"

# Delete all images
docker_clean()
{
	docker rm $(docker ps -a -q)
	docker rmi $(docker images -q)
}
echo -e "${CDC}docker_clean${CN}"

_sfmax()
{
	docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | grep -E '(^lg-|^NAME)' | sort -k "$1" -h
}

lgcpu() { _sfmax 3; }
lgmem() { _sfmax 4; }
lgio() { _sfmax 7; }
lgbio() { echo "========= INPUT"; _sfmax 8; echo "=========== OUTPUT"; _sfmax 10; }
echo -e "${CDC}lgcpu${CN}                                  # Sorted list of CPU usage"
echo -e "${CDC}lgmem${CN}                                  # Sorted list of MEM usage"
echo -e "${CDC}lgio${CN}                                   # Sorted list of Network OUT usage"
echo -e "${CDC}lgbio${CN}                                  # Sorted list of BlockIO usage"


sftop()
{
	docker run --rm -ti --name=ctop --volume /var/run/docker.sock:/var/run/docker.sock:ro   quay.io/vektorlab/ctop:latest
}
echo -e "${CDC}sftop${CN}"


