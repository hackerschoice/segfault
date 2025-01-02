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
unset _sf_isinit
_sf_region="$(hostname)"

_sf_deinit()
{
	unset CY CG CR CC CB CF CN CDR CDG CDY CDB CDM CDC CUL
	# Can not unset hash-maps here as those cant be declared inside a function.
	unset _sf_now _sf_isinit _sf_p2lid _sf_quota
}

_sf_init()
{
	_sf_now=$(date '+%s' -u)
	[[ -n $_sf_isinit ]] && return

	unset _sfquota _sf_p2lid
	declare -Ag _sfquota
	declare -Ag _sf_p2lid

	_sf_isinit=1

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
}

_sf_usage()
{
	[[ ! -t 1 ]] && return
	_sf_init

	echo -e "${CDC}container_df <regex>${CN}                   # eg \`container_df ^lg\`"
	echo -e "${CDC}lgwall [lg-LID] <message>${CN}              # eg \`lgwall lg-NGVlMTNmMj "'"Get\\nLost\\n"`'
	echo -e "${CDC}lgstop [lg-LID] <message>${CN}              # eg \`lgstop lg-NmEwNWJkMW "'"***ABUSE***\\nContact SysCops"`'
	echo -e "${CDC}lgban  [lg-LID] <message>${CN}              # Stop & Ban IP address, eg \`lgban lg-NmEwNWJkMW "'"***ABUSE***\\nContact SysCops"`'
	echo -e "${CDC}lgrm   [lg-LID]${CN}                        # Remove all data for LID"
	echo -e "${CDC}lgpurge <idle-days> <naughty-days>${CN}     # Purge LGs older than days or empty/full ones"
	echo -e "${CDC}lgps [ps regex] <stop> <message>${CN}       # eg \`lgps 'dd if=/dev/zero' stop "'"***ABUSE***\\nContact SysCops"`'
	echo -e "${CDC}lg_cleaner [max_pid_count=3] <stop>${CN}    # eg \`lg_cleaner 3 stop\` or \`lg_cleaner 0\`"
	echo -e "${CDC}docker_clean${CN}                           # Delete all containers & images"
	echo -e "${CDC}lgsh [lg-LID]${CN}                          # Enter bash [FOR TESTING]"
	echo -e "${CDC}lghst [regex]${CN}                          # grep in zsh_history [FOR TESTING]"
	echo -e "${CDC}lgx [regex]${CN}                            # Output LIDs that match process"
	echo -e "> ${CDR}"'for x in $(lgx "xmrig"); do lgban "$x" "Mining not allowed."; done'"${CN}"
	echo -e "${CDC}lgcpu${CN}                                  # Sorted list of CPU usage"
	echo -e "${CDC}lgmem${CN}                                  # Sorted list of MEM usage"
	echo -e "${CDC}lgdf <lg-LID>${CN}                          # Storage usage (Try '|sort -n -k3' for inode)"
	echo -e "${CDC}lgio${CN}                                   # Sorted list of Network OUT usage"
	echo -e "${CDC}lgbio${CN}                                  # Sorted list of BlockIO usage"
	echo -e "${CDC}lgiftop${CN}                                # Live network traffic"
	echo -e "${CDC}sftop${CN}"
	echo -e "${CDC}lghelp${CN}                                 # THIS HELP"
	# echo -e "${CDC}export ${CDY}SF_DRYRUN=1${CN}                     # Simulate only"

	_sf_deinit
}

lghelp() { _sf_usage; }

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

_sfcg_forall()
{
	local IFS
	local arr
	local l
	local a
	local ts
	local fn
	local skip_token
	local -

	skip_token="$1"

	set -o noglob
	IFS=$'\n' arr=($(docker ps --format "{{.Names}}"  --filter 'name=^lg-' 2>/dev/null))

	for l in "${arr[@]}"; do
		ts=2147483647
		[[ -n "$skip_token" ]] && [[ -e "${_sf_dbdir}/user/${l}/token" ]] && continue
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

	str=$(docker top "${lglid}" -e -o pid,bsdtime,rss,start_time,comm,cmd 2>/dev/null)
	[[ -n $str ]] && [[ -n $match ]] && [[ "$str"$'\n' =~ $match ]] && found=1

	echo "$str"
	return $found
}

### Return number of seconds the LG logged in last. 0 if currently logged in.
_sf_lastlog()
{
	local age
	local lglid
	lglid=$1
	[[ -f "${_sf_dbdir}/user/${lglid}/is_logged_in" ]] && { echo 0; return; }
	[[ ! -f "${_sf_dbdir}/user/${lglid}/ts_logout" ]] && { echo >&2 "[$lglid] WARN ts_logout not found"; echo 0; return; }
	age=$(date '+%s' -u -r "${_sf_dbdir}/user/${lglid}/ts_logout")
	echo $((_sf_now - age))
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
		local str
		local days
		lglid=$1

		age=$(_sf_lastlog "$lglid")
		if [[ $age -eq 0 ]]; then
			age_str="${CG}-online--"
		elif [[ $age -lt 3600 ]]; then
			# "59m59s"
			str="${age}     "
			age_str="${CY}   ${str:0:5}s"
		elif [[ $age -lt 86400 ]]; then
			age_str="${CDY}   $(date -d @"$age" -u '+%Hh%Mm')"
		else
			days=$((age / 86400))
			age_str="${CDR}${days}d $(date -d@"$age" -u '+%Hh%Mm')"
		fi

		[[ -f "${_self_for_guest_dir}/${lglid}/ip" ]] && ip=$(<"${_self_for_guest_dir}/${lglid}/ip")
		ip="${ip}                      "
		ip="${ip:0:16}"
		[[ -f "${_sf_dbdir}/user/${lglid}/hostname" ]] && hn=$(<"${_sf_dbdir}/user/${lglid}/hostname")
		hn="${hn}                      "
		hn="${hn:0:16}"
		[[ -f "${_self_for_guest_dir}/${lglid}/geoip" ]] && geoip=" $(<"${_self_for_guest_dir}/${lglid}/geoip")"
		fn="${_sf_dbdir}/user/${lglid}/created.txt"
		[[ -f "${fn}" ]] && t_created=$(date '+%F' -u -r "${fn}")
		[[ -f "${_self_for_guest_dir}/${lglid}/c_ip" ]] && cip=$(<"${_self_for_guest_dir}/${lglid}/c_ip")
		cip+="                         "
		cip=${cip:0:16}
		echo -e "${CDY}====> ${CDC}${t_created:-????-??-??} ${age_str}${CN} ${CDM}${lglid} ${CDB}${hn} ${CG}${ip} ${CF}${cip}${CDG}${geoip}${CN}"
}

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
	local fn
	[[ -z $2 ]] && { echo >&2 "lgwall LID [message]"; return; }
	cid=$(docker inspect --format='{{.Id}}' "$1") || return
	pid=$(<"/var/run/containerd/io.containerd.runtime.v2.task/moby/${cid}/init.pid") || return
	for fn in "/proc/${pid}/root/dev/pts"/*; do
		[[ "${fn##*/}" =~ [^0-9] ]] && continue
		[[ ! -c "$fn" ]] && continue
		hex=$(stat -c %t "$fn")
		maj="$((16#$hex))"
		[[ "$maj" -ge 136 ]] && [[ "$maj" -le 143 ]] && timeout 1 echo -e "\n@@@@@ SYSTEM MESSAGE\n${2}\n@@@@@" >>"${fn}"
	done
}

# Enter a docker network namespace
# [container] <cmd ...>
netns() {
	local pid
	local c_id
	c_id="$1"

	shift 1
	pid=$(docker inspect -f '{{.State.Pid}}' "${c_id:?}") || return
	nsenter -t "${pid}" -n "$@"
}

# Load xfs Project-id <-> LID mapping
# FIXME: could be loaded from user/prjid?
_sf_mkp2lid()
{
	local dst
	local l
	local IFS
	local all
	local str
	local -

	[[ ${#_sf_p2lid[@]} -gt 0 ]] && return # Already loaded
	echo >&2 "Loading Prj2Lid DB..."

	dst=$1
	[[ -z $dst ]] && dst="lg-*"

	IFS=""
	str=$(cd "${_sf_basedir}/data/user"; lsattr -dp "./"${dst})
	set -o noglob
	IFS=$'\n'
	all=($str)
	# Create hash-map to translate PRJID to LID name
	for l in "${all[@]}"; do
		# Trim whitespace from beginning.
		[[ ${l:0:1} == " " ]] && l="${l#"${l%%[![:space:]]*}"}"
		[[ ${l%% *} == "0" ]] && { echo "Warning: ${l##*/} with PRJ-ID==0"; sleep 10; continue; }
		_sf_p2lid["${l%% *}"]="${l##*/}"
	done
	return 255
}

# Create hash-maps for BYTES and INODES by LG
_sf_load_xfs_usage()
{
	local arr prjid perctt lid
	local all
	local IFS
	local l
	local lid
	local -

	[[ ${#_sfquota[@]} -gt 0 ]] && return
	_sf_mkp2lid "$1"
	echo >&2 "Loading XFS Quota DB..."
	set -o noglob

	IFS=$'\n'
	all=($(xfs_quota -x -c "report -p -ibnN ${_sf_basedir}/data"))
	echo >&2 "Entries XFS: ${#all[@]}"
	unset IFS
	for l in "${all[@]}"; do
		[[ -z $l ]] && continue
		arr=($l)
		prjid=${arr[0]##*#}
		# [[ -z ${_sf_p2lid[$prjid]} ]] && { echo >&2 "$l: prjid=${prjid} on has not LID?"; continue; }
		[[ -z ${_sf_p2lid["$prjid"]} ]] && continue;
		lid="${_sf_p2lid["$prjid"]}"

		# Check if quota is missing (and force to 100.00%)
		[[ ${arr[1]} -eq 0 ]] && continue
		[[ ${arr[3]} -le 0 ]] && { echo >&2 "WARN [${lid}]#$prjid: Missing quota"; arr[3]=${arr[1]}; continue; }
		[[ ${arr[8]} -le 0 ]] && { echo >&2 "WARN [${lid}]#$prjid: Missing iquota"; arr[8]=${arr[6]}; }

		_sfquota["${lid}-blocks"]="${arr[1]}"
		_sfquota["${lid}-blocks-perctt"]="$((arr[1] * 10000 / arr[3]))"
		_sfquota["${lid}-inode"]="${arr[6]}"
		_sfquota["${lid}-inode-perctt"]="$((arr[6] * 1000 / arr[8]))"
	done
}

# Clean old and stale files
_lgclean() {
    local IFS
	local arr
	local l

    arr=($(find "${_sf_dbdir:?}/user" -maxdepth 2 -name is_logged_in))
	IFS=$'\n'
	for l in "${arr[@]}"; do
		l="${l%/is_logged_in}"
		l="${l##*/lg-}"
		docker inspect "lg-${l}" &>/dev/null && continue
		echo -e "[${CDM}lg-${l}${CN}] Deleting stale ${CDY}${CF}is_logged_in${CN}"
		# We missed to set the ts_logout. Do our best to set it to NOW
		# so that lgpurge wont delete a stale LG immediately.

		# debuging:
		# [[ ! -f "${_sf_dbdir:?}/user/lg-${l}/ts_logout" ]] && mv rm -f "${_sf_dbdir:?}/user/lg-${l}/is_logged_in" "${_sf_dbdir:?}/user/lg-${l}/ts_logout"
		[[ ! -f "${_sf_dbdir:?}/user/lg-${l}/ts_logout" ]] && touch "${_sf_dbdir:?}/user/lg-${l}/ts_logout"
		rm -f "${_sf_dbdir:?}/user/lg-${l}/is_logged_in"
	done
}

lgclean() {
	_sf_init
	_lgclean
	_sf_deinit
}

# [Idle-DAYS] [Naughty-Days]
# - Delete all LID's that have not been logged in for Idle-Days
# - Delete all LID's that have not been used for Naughty-Days and look empty (blocks <= 180)
# - Delete all LID's that have not been used for Naughty-Days and occupy 100% quota.
lgpurge()
{
	local age_purge
	local age_naughty
	local pdays ndays
	local IFS
	local arr
	local dbr
	local age
	local i
	local blocks_purge
	local lg_purge
	local is_purge
	local str
	
	_sf_init
	_lgclean

	pdays=$1
	{ [[ -z $pdays ]] || [[ $pdays -lt 10 ]]; } && pdays=30
	age_purge=$((pdays * 24 * 60 * 60))
	ndays=$2
	{ [[ -z $ndays ]] || [[ $ndays -lt 1 ]]; } && ndays=10
	age_naughty=$((ndays * 24 * 60 * 60))

	## Check that data/user/lg-* and config/db/user/lg-* is syncronized
	IFS=" "
	arr=($(cd "${_sf_basedir}/data/user/"; echo lg-*))
	{ [[ ${#arr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/data/user/lg-*" ]]; } && { echo >&2 "WARN1: No lg's found"; return; }
	dbr=($(cd "${_sf_basedir}/config/db/user/"; echo lg-*))
	{ [[ ${#dbr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/config/db/user/lg-*" ]]; } && { echo >&2 "WARN2: No lg's found"; return; }
	[[ ${#arr[@]} -ne ${#dbr[@]} ]] && {
		echo >&2 "WARN: data/user/lg-* (${#arr[@]}) and config/db/user/lg-* (${#dbr[@]}) differ."
		[[ -z $SF_FORCE ]] && echo -e >&2 "Set ${CDC}SF_FORCE=1${CN} to delete"
		# Note: This should never really happen unless encfs fails?
		[[ -n $SF_FORCE ]] && {
			str=${arr[*]}
			for l in "${dbr[@]}"; do
				[[ "${str}" == *"$l"* ]] && continue
				echo "[$l] Not found in data/user/$l"
				_sf_lgrm "$l"
			done
			str="${dbr[*]}"
			for l in "${arr[@]}"; do
				[[ "${str}" == *"$l"* ]] && continue
				echo "[$l] Not found in config/db/user/$l"
				_sf_lgrm "$l"
			done
		}
	}
	unset dbr

	_sf_load_xfs_usage

	# echo "Entries: ${#_sfquota[@]} and ${#_sf_p2lid[@]}"
	echo >&2 "Checking for LIDs idle more than ${pdays} days or naughty LIDs idle more than ${ndays} days..."
	i=0
	blocks_purge=0
	lg_purge=0
	while [[ $i -lt ${#arr[@]} ]]; do
		l=${arr[$i]}
		((i++))
		echo -en "\r${i}/${#arr[@]} "
		age=$(_sf_lastlog "$l")
		# Note: The following error appears in older SF versions when two different SECRETs
		# could generate the same SF_NUM / SF_HOSTNAME. The implication is that both 
		[[ -z "${_sfquota["${l}-blocks"]}" ]] && { echo >&2 "[$l] XFS PrjID does not exist"; continue; }
		[[ $age -lt ${age_naughty:?} ]] && continue

		unset is_purge
		if [[ $age -gt ${age_purge:?} ]]; then
			is_purge="${CDG}to old"
		elif [[ ${_sfquota["${l}-blocks"]} -lt 180 ]]; then
			is_purge="${CDY}empty"
		elif [[ ${_sfquota["${l}-blocks-perctt"]} -gt 9900 ]]; then
			is_purge="${CDR}100% usage"
		elif [[ ${_sfquota["${l}-inode-perctt"]} -gt 9900 ]]; then
			is_purge="${CDR}100% inode usage"
		else
			continue
		fi
		n=${_sfquota["${l}-blocks"]}
		((blocks_purge+=n))
		echo -e "\r$((age / 86400)) days [${CDM}$l${CN}] blocks=${_sfquota["${l}-blocks"]} (${is_purge}${CN})"
		((lg_purge++))
		[[ -n $SF_DRYRUN ]] && continue
		_sf_lgrm "${l}"
	done
	echo ""
	echo "Purged ${lg_purge} LIDS and a total of ${blocks_purge} blocks..."

	_sf_deinit
}

#                               Blocks                                          Inodes
# Project ID       Used       Soft       Hard    Warn/Grace           Used       Soft       Hard    Warn/ Grace	
# #9                   0    0    4194304     00 [--------]          0          0      65536     00 [--------]
lgdf()
{
	local arr
	local psz
	local pin
	local perctt
	local str
	local l
	local dst
	local IFS
	local blocks
	local fn
	local info

	_sf_init

	dst="$1"
	if [[ -z $dst ]]; then
		IFS=" "
		arr=($(cd "${_sf_basedir}/data/user/"; echo lg-*))
		{ [[ ${#arr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/data/user/l-*" ]]; } && { echo >&2 "WARN: No lg's found"; return; }
	else
		arr=("$dst")
	fi
	_sf_load_xfs_usage "$dst"

	i=0
	while [[ $i -lt ${#arr[@]} ]]; do
		l=${arr[$i]}
		((i++))
		str="${_sfquota["${l}-blocks"]}             "
		blocks="${str:0:10} "
		perctt=${_sfquota["${l}-blocks-perctt"]}
		psz=$(printf '% 3u.%02u\n' $((perctt / 100)) $((perctt % 100)))
		perctt=${_sfquota["${l}-inode-perctt"]}
		pin=$(printf '% 3u.%02u\n' $((perctt / 100)) $((perctt % 100)))
		str="${psz}    "
		info="${l}"
		fn="${_sf_dbdir}/user/${l}/hostname"
		[[ -f "$fn" ]] && info+=" $(<"$fn")"
		fn="${_sf_dbdir}/user/${l}/token"
		[[ -f "$fn" ]] && info+=" [$(<"$fn")]"
		echo "${blocks} ${str:0:5}% ${pin}% ${info}"
	done

	_sf_deinit
}

_sf_lgrm()
{
	local l
	local fn
	local hn

	l="$1"
	[[ -z $l ]] && return

	fn="${_sf_dbdir}/user/${l}/hostname"
	[[ -z $SF_FORCE ]] && [[ -e "${_sf_dbdir}/user/${l}/token" ]] && {
		echo -e >&2 "${CDR}ERROR:${CN} ${l} has a TOKEN and is likely a valued user. Set ${CDC}SF_FORCE=1${CN} to force-rm."
		return
	}
	[[ -f "$fn" ]] && hn="$(<"$fn")"
	[[ -n $hn ]] && {
		_sf_xrm "${_sf_dbdir}/hn/hn2lid-${hn}"
		_sf_xrmdir "${_sf_shmdir}/encfs-sec/www-root/www/${hn,,}"
		_sf_xrmdir "${_sf_shmdir}/encfs-sec/everyone-root/everyone/${hn}"
	}

	_sf_xrmdir "${_sf_basedir}/data/user/${l}"
	_sf_xrm "${_sf_dbdir}/cg/${l}.txt"
	_sf_xrmdir "${_sf_dbdir}/user/${l}"

}

lgrm()
{
	_sf_init
	_sf_lgrm "$1"
	_sf_deinit
}

lgban()
{
	local fn
	local hn
	local ip
	local msg
	local lglid="${1}"

	_sf_init
	shift 1

	[[ -z $SF_FORCE ]] && [[ -e "${_sf_dbdir}/user/${lglid}/token" ]] && {
		echo -e >&2 "ERROR: ${lglid} has a TOKEN and is likely a valued user. Set ${CDC}SF_FORCE=1${CN} to force-ban."
		return
	}
	fn="${_self_for_guest_dir}/${lglid}/ip"
	[[ -f "$fn" ]] && {
		ip=$(<"$fn")
		fn="${_self_for_guest_dir}/${lglid}/hostname"
		[[ -f "${fn}" ]] && hn=$(<"${fn}")
		fn="${_sf_dbdir}/banned/ip-${ip:0:18}"
		[[ ! -e "$fn" ]] && {
			[[ $# -gt 0 ]] && msg="$*\n"
			echo -en "# ${CY}${hn:-NAME} ${CDY}${_sf_region:-REGION} ${lglid} ${ip:0:18}${CN}\n$msg" >"${fn}"
		}
		echo "Banned: $ip"
	}

	lgstop "${lglid}" "$@"
	#_sf_lgrm "${lglid}" # Dont lgrm here and give user chance to explain to re-instate his server.

	_sf_deinit
}
# FIXME: check if net-a.b.c should be created instead to ban entire network.


# <lg-LID> <MESSAGE>
lgstop()
{
	local l="${1:?}"

	[[ -z $SF_FORCE ]] && [[ -e "${_sf_dbdir}/user/${l}/token" ]] && {
		echo -e >&2 "${CDR}ERROR:${CN} ${l} has a TOKEN and is likely a valued user. Set ${CDC}SF_FORCE=1${CN} to force-rm."
		return
	}

	[[ -n $2 ]] && {
		lgwall "${1}" "$2"
		echo -e "$2" >"${_sf_dbdir}/user/${1}/syscop-msg.txt"
		docker top "$1" -e -o pid,ppid,%cpu,rss,start_time,exe,comm,cmd | cut -c -512  >"${_sf_dbdir}/user/${1}/syscop-ps.txt"
	}
	docker stop "${1}"
}



lgls()
{
    local IFS
	local arr

	_sf_init
    IFS=$'\n' arr=($(_sfcg_forall))
	for lglid in "${arr[@]}"; do
        _sfcfg_printlg "$lglid"
	done

	_sf_deinit
}

# Show all LID where REGEX matches a process+arguments and optionally stop
# the container.
# [<REGEX>] <stop> <stop-message-to-user>
lgps()
{
	local lglid
	local match
	local stoparr
	local msg
	local is_stop
	local str
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
	local skip_token
    local IFS
	match="$1"
	skip_token="$2"

	_sf_init
	[[ -z $match ]] && return

    IFS=$'\n' arr=($(_sfcg_forall "$skip_token"))
	for lglid in "${arr[@]}"; do
		_sfcg_psarr "$lglid" "$match" >/dev/null && continue
		echo "$lglid "
        echo >&2 $(_sfcfg_printlg "$lglid")
	done

	_sf_deinit
}

lgiftop()
{
	_sf_init

	echo -e "==> ${CDY}Press t & s after startup.${CN}"
	echo "Press enter to continue."
	read -r
	TERM=xterm-256color nsenter -t $(docker inspect -f '{{.State.Pid}}' sf-router) -n iftop -Bn -i eth3

	_sf_deinit
}

# Stop all container that have no SSH connection and only 3 processes (init, sleep, zsh)
# NOTE: This should not happen any longer since a bug in docker-sigproxy got fixed.
# Example: lg_cleaner
# Example: lg_cleaner stop
lg_cleaner()
{
	local is_stop
	local max
	local IFS
	local -
	max="$1"
	is_stop="$2"
	[[ -z $max ]] && max=3
	set -o noglob
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

# Convert a PID to a LG
pid2lg()
{
	local p c str
	p=$1
	c=$(grep docker- "/proc/${p}/cgroup")
	[[ -z $c ]] && { echo "LG-NOT-FOUND"; return 255; }
	c=${c##*docker-}
	c=${c%\.scope}
	str=$(docker inspect "$c" -f '{{.Name}}')
	basename "$str"
}

# grep through all environ of first child of sshd
lgenv()
{
	local x y p match
	for x in /proc/*/exe; do
		[[ $(readlink "$x") != "/usr/sbin/sshd" ]] && continue
		p=$(dirname "$x")
		p=${p##*\/}
		for y in $(<"/proc/${p}/task/${p}/children"); do
			strings "/proc/${y}/environ" | grep "$@" || continue
			echo "$y $(pid2lg "$y") $(strings /proc/${y}/environ| grep SSH_CONNECTION)"
			break
		done	
	done
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
