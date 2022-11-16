#! /bin/bash

[[ $(basename -- "$0") == "funcs_admin.sh" ]] && { echo "ERROR. Use \`source $0\` instead."; exit 1; }
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd)"
source "${BASEDIR}/funcs.sh"

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
echo -e "${CDC}container_df <regex>${CN}        # eg \`container_df ^lg\`"

# Send a message to all PTS of a specific container
# Example: lgwall lg-NGVlMTNmMj "Get \nlost\n"
# [LID] [message]
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
		[[ "$maj" -ge 136 ]] && [[ "$maj" -le 143 ]] && echo -e "$2" >>"${fn}"
	done
}
echo -e "${CDC}lgwall <LID> <message>${CN}      # eg \`lgwall lg-NGVlMTNmMj "'"Get\\nLost\\n"`'

# 
# Show all LID where REGEX matches a process+arguments and optionally stop
# the container.
# Example: plgtop urandom
# Example: plgtop urandom stop
# [<REGEX>] <stop>
plgtop()
{
	systemd-cgls -l -u docker_limit.slice | while read x; do
		[[ $x == *" [init-"* ]] && { lid="${x#* \[init-}"; lid="${lid%%-*}"; }
		[[ ! $x =~ ${1:?} ]] && continue
		[[ ${#lid} -ne 10 ]] && continue

		echo "====> lg-${lid}"
		docker top "lg-${lid}" | grep -E "${1:?}"'|$'
		[[ -n $2 ]] && docker stop "lg-${lid}"
		unset lid
	done
}
echo -e "${CDC}plgtop <ps regex> [stop]${CN}    # eg \`plgtop 'dd if=/dev/zero' stop\`"

#plgtop "/bin/bash /everyone" stop                # Example
#plgtop "dd if=/dev/zero of=/dev/null" stop
#plgtop "bzip2 -9" stop

# Show user's IP by matching process+argument
# Example: plgip urandom
plgip()
{
	systemd-cgls -l | while read x; do
		[[ $x == *" [init-"* ]] && { lid="${x#* \[init-}"; lid="${lid%%-*}"; }
		[[ ! $x =~ ${1:?} ]] && continue
		[[ ${#lid} -ne 10 ]] && continue

		fn="/dev/shm/sf-u1000/self-for-guest/lg-${lid}/ip"
		[[ -f "$fn" ]] && ip=$(<"$fn") || ip="Not Found"
		echo "lg-$lid $ip"
		unset lid
	done
}
echo -e "${CDC}plgip <ps regex>${CN}            # eg \`plgip 'dd if=/dev/zero'\`"


# Stop all container that have no SSH connection and only 3 processes (init, sleep, zsh)
# NOTE: This should not happen any longer since a bug in docker-sigproxy got fixed.
# Example: lg_cleaner
# Example: lg_cleaner stop
lg_cleaner()
{
	local is_stop
	is_stoop="$1"
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
		[[ $n -gt 3 ]] && continue
		echo "===========Stopping $x n=$n"
		docker top "$x"
		[[ -n $is_stop ]] && docker stop -t1 "$x"
	done
}
echo -e "${CDC}lg_cleaner [stop]${CN}"

# Stop all container that have no SSH connection 
# Example: lg_nossh
# Example: lg_nossh stop
lg_nossh()
{
	local is_stop
	is_stoop="$1"
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
		echo "=========== $x n=$n"
		docker top "$x"
	done
}
echo -e "${CDC}lg_nossh${CN}"

# Delete all images
docker_clean()
{
	docker rm $(docker ps -a -q)
	docker rmi $(docker images -q)
}
echo -e "${CDC}docker_clean${CN}"

sftop()
{
	docker run --rm -ti --name=ctop --volume /var/run/docker.sock:/var/run/docker.sock:ro   quay.io/vektorlab/ctop:latest
}
echo -e "${CDC}sftop${CN}"


