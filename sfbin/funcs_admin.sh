#! /bin/bash

[[ $(basename -- "$0") == "funcs_admin.sh" ]] && { echo "ERROR. Use \`source $0\` instead."; exit 1; }
_basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd)"
# shellcheck disable=SC1091 # Do not follow
# source "${_basedir}/funcs.sh"
unset _basedir

_cgbdir="/sys/fs/cgroup"
[[ -d /sys/fs/cgroup/unified/ ]] && _cgbdir="/sys/fs/cgroup/unified"
_sf_shmdir="/dev/shm/sf-u1000"
[[ -d "/dev/shm/sf" ]] && _sf_shmdir="/dev/shm/sf"
_self_for_guest_dir="${_sf_shmdir}/self-for-guest"
_sf_basedir="/sf"
_sf_dbdir="${_sf_basedir}/config/db"

_sf_deinit()
{
	unset CY CG CR CC CB CF CN CDR CDG CDY CDB CDM CDC CUL
	unset _sf_now _sf_isinit
}

_sf_init()
{
	_sf_now=$(date '+%s' -u)
	[[ -n $_sf_isinit ]] && return
	[[ ! -t 1 ]] && return

	CY="\e[1;33m" # yellow
	CG="\e[1;32m" # green
	CR="\e[1;31m" # red
	CC="\e[1;36m" # cyan
	CM="\e[1;35m" # magenta
	CW="\e[1;37m" # white
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

	_sf_isinit=1
}

_sf_usage()
{
	[[ ! -t 1 ]] && return
	_sf_init

	echo -e "${CDC}container_df <regex>${CN}                   # eg \`container_df ^lg\`"
	echo -e "${CDC}lgwall [lg-LID] <message>${CN}              # eg \`lgwall lg-NGVlMTNmMj "'"Get\\nLost\\n"`'
	echo -e "${CDC}lgstop [lg-LID] <message>${CN}              # eg \`lgstop lg-NmEwNWJkMW "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lgban  [lg-LID] <message>${CN}              # Stop & Ban IP address, eg \`lgban lg-NmEwNWJkMW "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lgrm   [lg-LID]${CN}                        # Remove all data for LID"
	echo -e "${CDC}lgps [ps regex] <stop> <message>${CN}       # eg \`lgps 'dd if=/dev/zero' stop "'"***ABUSE***\\nContact Sysop"`'
	echo -e "${CDC}lg_cleaner [max_pid_count=3] <stop>${CN}    # eg \`lg_cleaner 3 stop\` or \`lg_cleaner 0\`"
	echo -e "${CDC}docker_clean${CN}                           # Delete all containers & images"
	echo -e "${CDC}lgsh [lg-LID]${CN}                          # Enter bash [FOR TESTING]"
	echo -e "${CDC}lghst [regex]${CN}                          # grep in zsh_history [FOR TESTING]"
	echo -e "${CDC}lgx [regex]${CN}                            # Output LIDs that match process"
	echo -e "> ${CDR}"'for x in $(lgx xmrig); do lgban "$x" "Mining not allowed."; done'"${CN}"
	echo -e "${CDC}lgcpu${CN}                                  # Sorted list of CPU usage"
	echo -e "${CDC}lgmem${CN}                                  # Sorted list of MEM usage"
	echo -e "${CDC}lgdf <lg-LID>${CN}                          # Storage usage (Try '|sort -n -k3' for inode)"
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

#                               Blocks                                          Inodes
# Project ID       Used       Soft       Hard    Warn/Grace           Used       Soft       Hard    Warn/ Grace	
# #9                   0    0    4194304     00 [--------]          0          0      65536     00 [--------]
lgdf()
{
	local l
	local arr
	local psz
	local pin
	local perctt
	local p2lid
	local str
	local lid
	local dst

	_sf_init
	dst="$1"
	[[ -z $dst ]] && dst="lg-*"
	declare -A p2lid

	# Create map to translate PRJID to LID name
	eval p2lid=( $(lsattr -dp "${_sf_basedir}/data/user"/${dst} | while read l; do
		echo -n "['${l%% *}']='${l##*/}' "
	done;) )

	xfs_quota -x -c "report -p -ibnN ${_sf_basedir}/data" | while read l; do
		[[ -z $l ]] && continue
		arr=($l)
		# #10041175
		prjid=${arr[0]##*#}
		[[ -z ${p2lid[$prjid]} ]] && continue
		lid="${p2lid[$prjid]}"

		# Check if quota is missing (and force to 100.00%)
		[[ ${arr[1]} -eq 0 ]] && continue
		[[ ${arr[3]} -le 0 ]] && { echo >&2 "WARN [${lid}]#$prjid: Missing quota"; arr[3]=${arr[1]}; }
		perctt=$((arr[1] * 10000 / arr[3]))
		psz=$(printf '% 3u.%02u\n' $((perctt / 100)) $((perctt % 100)))

		[[ ${arr[8]} -le 0 ]] && { echo >&2 "WARN [${lid}]#$prjid: Missing iquota"; arr[8]=${arr[6]}; }
		perctt=$((arr[6] * 10000 / arr[8]))
		pin=$(printf '% 3u.%02u\n' $((perctt / 100)) $((perctt % 100)))

		str="${arr[1]}          "
		l="${str:0:10} "
		str="${psz}       "
		echo "${l} ${str:0:5}% ${pin}%  ${lid}"
	done

	_sf_deinit
}

# <lg-LID> <MESSAGE>
lgstop()
{
	[[ -n $2 ]] && { lgwall "${1}" "$2"; }
	docker stop "${1}"
}

_sf_xrmdir()
{
	[[ ! -d "${1:?}" ]] && return
	rm -rf "${1}"
}

_sf_xrm()
{
	[[ ! -f "${1:?}" ]] && return
	rm -f "${1}"
}

lgrm()
{
	local l
	local fn
	local hn

	_sf_init
	l="$1"
	[[ -z $l ]] && return

	fn="${_sf_dbdir}/user/${l}/hostname"
	[[ -f "$fn" ]] && hn="$(<"$fn")"
	[[ -n $hn ]] && {
		_sf_xrm "${_sf_dbdir}/hn/hn2lid-${hn}"
		_sf_xrmdir "${_sf_shmdir}/encfs-sec/www-root/www/${hn,,}"
		_sf_xrmdir "${_sf_shmdir}/encfs-sec/everyone-root/everyone/${hn}"
	}

	_sf_xrmdir "${_sf_basedir}/data/user/${l}"
	_sf_xrm "${_sf_dbdir}/cg/${l}.txt"
	_sf_xrmdir "${_sf_dbdir}/user/${l}"

	_sf_deinit
}

lgban()
{
	local fn
	local ip
	local msg
	local lid

	lid="${1}"
	shift 1

	fn="${_self_for_guest_dir}/${lid}/ip"
	[[ -f "$fn" ]] && {
		ip=$(<"$fn")
		fn="${_sf_dbdir}/banned/ip-${ip:0:18}"
		[[ ! -e "$fn" ]] && {
			[[ $# -gt 0 ]] && msg="$*\n"
			echo -en "$msg" >"${fn}"
		}
		echo "Banned: $ip"
	}

	lgstop "${lid}" "$@"
	lgrm "${lid}"
}
# FIXME: check if net-a.b.c should be created instead to ban entire network.

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
		fn="${_sf_dbdir}/user/${l}/created.txt"
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
		local age
		local age_str
		local days
		lglid=$1

		[[ ! -f "${_sf_dbdir}/user/${lglid}/is_logged_in" ]] && {
			age=$(date '+%s' -u -r "${_sf_dbdir}/user/${lglid}/ts_logout")
			age=$((_sf_now - age))
			if [[ $age -lt 3600 ]]; then
				# "59m59s"
				str="${age}     "
				age_str="${CY}   ${str:0:5}s"
			elif [[ $age -lt 86400 ]]; then
				age_str="${CDY}   $(date -d @"$age" -u '+%Hh%Mm')"
			else
				days=$((age / 86400))
				age_str="${CDR}${days}d $(date -d@"$age" -u '+%Hh%Mm')"
			fi
		}
		#                     
		[[ -z $age ]] && age_str="${CG}-online--"
		[[ -f "${_self_for_guest_dir}/${lglid}/ip" ]] && ip=$(<"${_self_for_guest_dir}/${lglid}/ip")
		ip="${ip}                      "
		ip="${ip:0:16}"
		[[ -f "${_sf_dbdir}/user/${lglid}/hostname" ]] && hn=$(<"${_sf_dbdir}/user/${lglid}/hostname")
		hn="${hn}                      "
		hn="${hn:0:16}"
		[[ -f "${_self_for_guest_dir}/${lglid}/geoip" ]] && geoip=" $(<"${_self_for_guest_dir}/${lglid}/geoip")"
		fn="${_sf_dbdir}/user/${lglid}/created.txt"
		[[ -f "${fn}" ]] && t_created=$(date '+%F %T' -u -r "${fn}")
		echo -e "${CDY}====> ${CDC}${t_created:-????-??-?? ??-??-??} ${age_str}${CN} ${CDM}${lglid} ${CDB}${hn} ${CG}${ip} ${CDG}${geoip}${CN}"
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
	local IFS
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

lgx()
{
	local lglid
	local match
    local IFS
	match="$1"

	_sf_init
	[[ -z $match ]] && return

    IFS=$'\n' arr=($(_sfcg_forall))
	for lglid in "${arr[@]}"; do
		_sfcg_psarr "$lglid" "$match" >/dev/null && continue
		echo "$lglid "
        echo >&2 $(_sfcfg_printlg "$lglid")
	done

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
	echo "May want to ${CDC}docker system prune -f -a${CN}"
}

# [Sort Row] <info-string> <Keep Stats>
_sfmax()
{
	local s
	s="${CN}"
	[[ -n $2 ]] && s="         ${CN}(${CDR}$2${CN})"
	[[ -z $_sf_stats ]] && _sf_stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | grep ^lg-)
	echo "$_sf_stats" | sort -k "$1" -h
	echo -e "${CDG}NAME                CONTAINER      CPU %     MEM %     NET I/O           BLOCK I/O${s}"
	[[ -z $3 ]] && unset _sf_stats
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
	cd "${_sf_shmdir}/encfs-sec" || return
	for d in lg-*; do
		_grephst "$1" "${d}/root/.zsh_history"
	done
}

lgcpu() { _sf_init; _sfmax 3; _sf_deinit; }
lgmem() { _sf_init; _sfmax 4; _sf_deinit; }
lgio()  { _sf_init; _sfmax 5 "INPUT" 1; _sfmax 7  "OUTPUT"; _sf_deinit; }
lgbio() { _sf_init; _sfmax 8 "INPUT" 1; _sfmax 10 "OUTPUT"; _sf_deinit; }


sftop()
{
	docker run --rm -ti --name=ctop --volume /var/run/docker.sock:/var/run/docker.sock:ro   quay.io/vektorlab/ctop:latest
}

_sf_usage
