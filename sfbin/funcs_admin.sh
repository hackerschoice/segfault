#! /bin/bash

[ -z "$BASH_VERSION" ] && { echo >&2 "ERROR: Use bash"; return; exit 1; }
[[ $(basename -- "$0") == "funcs_admin.sh" ]] && { echo "ERROR. Use \`source $0\` instead."; return; exit 1; }
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

_sf_deinit() {
	[ -n "$SF_NOINIT" ] && return
	unset CY CG CR CC CB CF CN CDR CDG CDY CDB CDM CDC CUL
	# Can not unset hash-maps here as those cant be declared inside a function.
	unset _sf_now _sf_isinit _sf_p2lid _sf_quota
}

_sf_init() {
	local fn
	[ -n "$SF_NOINIT" ] && return

	_sf_now=$(date '+%s' -u)
	[[ -n $_sf_isinit ]] && return

	unset _sfquota _sf_p2lid
	declare -Ag _sfquota
	declare -Ag _sf_p2lid

	fn="${_sf_basedir}/config/.env_tg"
	[ -z "$TG_TOKEN" ] && [ -f "${fn}" ] && source "$fn"

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
	local IFS=$'\n'
	local arr
	local l
	local a
	local ts
	local fn
	local skip_token
	local -

	skip_token="$1"

	set -o noglob
	mapfile -t arr < <(docker ps --format "{{.Names}}"  --filter 'name=^lg-' 2>/dev/null)

	for l in "${arr[@]}"; do
		ts=2147483647
		[[ -n "$skip_token" ]] && [[ -e "${_sf_dbdir}/user/${l}/token" ]] && continue
		fn="${_sf_dbdir}/user/${l}/created.txt"
		[[ -f "$fn" ]] && ts="$(date +%s -u -r "$fn")"
		a+=("$ts $l")
	done
	echo "${a[*]}" | sort -n | cut -f2 -d" "
}

# [LG-LID]
_sfcg_psarr()
{
	local found=0
	local lglid="$1"
	local match="$2"
	local IFS
	[[ -z $match ]] && found=1 # empty string => Show all

	SF_G_PS="$(docker top "${lglid}" -e -o pid,bsdtime,rss,start_time,comm,cmd 2>/dev/null)"
	[[ -n $SF_G_PS ]] && [[ -n $match ]] && [[ "$SF_G_PS"$'\n' =~ $match ]] && found=1

	echo "$SF_G_PS"
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

_sf_loaduserinfo() {
	local lglid="${1:?}"
	local fn age days str color

	age=$(_sf_lastlog "$lglid")
	if [[ $age -eq 0 ]]; then
		age_str_nc="-online--"
		color="${CG}"
	elif [[ $age -lt 3600 ]]; then
		# "59m59s"
		str="${age}     "
		age_str_nc="   ${str:0:5}s"
	elif [[ $age -lt 86400 ]]; then
		age_str_nc="   $(date -d @"$age" -u '+%Hh%Mm')"
	else
		days=$((age / 86400))
		age_str_nc="${days}d $(date -d@"$age" -u '+%Hh%Mm')"
		color="${CDR}"
	fi
	age_str="${color:-${CY}}${age_str_nc}"

	[[ -f "${_self_for_guest_dir}/${lglid}/ip" ]] && ip=$(<"${_self_for_guest_dir}/${lglid}/ip")
	[[ -f "${_sf_dbdir}/user/${lglid}/hostname" ]] && hn=$(<"${_sf_dbdir}/user/${lglid}/hostname")
	hn="${hn}                      "
	hn="${hn:0:16}"
	[[ -f "${_self_for_guest_dir}/${lglid}/geoip" ]] && geoip=" $(<"${_self_for_guest_dir}/${lglid}/geoip")"


	fn="${_sf_dbdir}/user/${lglid}/created.txt"
	[[ -f "${fn}" ]] && t_created=$(date '+%F' -u -r "${fn}")
	[[ -f "${_self_for_guest_dir}/${lglid}/c_ip" ]] && cip=$(<"${_self_for_guest_dir}/${lglid}/c_ip")
	cip+="                         "
	cip=${cip:0:16}
}

_sfcfg_printlg() {
	local lglid="${1:?}"
	local geoip ip hn age_str t_created cip

	# sets age_str, ip, hn, cip, geoip
	_sf_loaduserinfo "${lglid}"
	ip="${ip}                      "
	ip="${ip:0:16}"

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
	local all
	local -

	[[ ${#_sf_p2lid[@]} -gt 0 ]] && return # Already loaded
	echo >&2 "Loading Prj2Lid DB..."

	dst=$1
	[[ -z $dst ]] && dst="lg-*"

	mapfile -t all < <(cd "${_sf_basedir}/data/user" && lsattr -dp "./"${dst})
	set -o noglob
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
	local is_warn_once
	local -

	[[ ${#_sfquota[@]} -gt 0 ]] && return
	_sf_mkp2lid "$1"
	echo >&2 "Loading XFS Quota DB..."
	set -o noglob

	mapfile -t all < <(xfs_quota -x -c "report -p -ibnN ${_sf_basedir}/data")
	echo >&2 "Entries XFS: ${#all[@]}"
	unset IFS
	for l in "${all[@]}"; do
		[[ -z $l ]] && continue
		arr=($l)
		prjid=${arr[0]:1} # Remove leading '#'
		{ [ -z "$prjid" ] || [ "$prjid" = "0" ]; } && continue
		# [[ -z ${_sf_p2lid[$prjid]} ]] && { echo >&2 "$l: prjid=${prjid} on has not LID?"; continue; }
		[[ -z ${_sf_p2lid["$prjid"]} ]] && {
			[ "${arr[1]}" -ne 0 ] && {
					[ -z "$is_warn_once" ] && { echo >&2 "WARN: These project-ids have no LID but consumes blocks (docker overlays?)."; is_warn_once=1; }
					# FIXME: These are likely mounted docker volumes
					echo "$l"
			}
			continue;
		}
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

    mapfile -t arr < <(find "${_sf_dbdir:?}/user" -maxdepth 2 -name is_logged_in)
	# IFS=$'\n'
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
	IFS=' ' read -r -a arr <  <(cd "${_sf_basedir}/data/user/" && echo lg-*)
	{ [[ ${#arr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/data/user/lg-*" ]]; } && { echo >&2 "WARN1: No lg's found"; return; }
	IFS=' ' read -r -a dbr <  <(cd "${_sf_basedir}/config/db/user/" && echo lg-*)
	{ [[ ${#dbr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/config/db/user/lg-*" ]]; } && { echo >&2 "WARN2: No lg's found"; return; }
	[[ ${#arr[@]} -ne ${#dbr[@]} ]] && {
		echo >&2 "WARN: data/user/lg-* (${#arr[@]}) and config/db/user/lg-* (${#dbr[@]}) differ."
		[[ -z $SF_FORCE ]] && echo -e >&2 "Set ${CDC}SF_FORCE=1${CN} to delete"
		# Note: This should never really happen unless encfs fails?
		str=${arr[*]}
		for l in "${dbr[@]}"; do
			[[ "${str}" == *"$l"* ]] && continue
			echo "[$l] Not found in data/user/$l"
			[ -n "$SF_FORCE" ] && _sf_lgrm "$l"
		done
		str="${dbr[*]}"
		for l in "${arr[@]}"; do
			[[ "${str}" == *"$l"* ]] && continue
			echo "[$l] Not found in config/db/user/$l"
			[ -n "$SF_FORCE" ] && _sf_lgrm "$l"
		done
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
	local totalb=0

	_sf_init

	dst="$1"
	if [[ -z $dst ]]; then
		IFS=' ' read -r -a arr <  <(cd "${_sf_basedir}/data/user/" && echo lg-*)
		{ [[ ${#arr[@]} -eq 0 ]] || [[ ${arr[0]} == "${_sf_basedir}/data/user/lg-*" ]]; } && { echo >&2 "WARN: No lg's found"; return; }
	else
		arr=("$dst")
	fi
	_sf_load_xfs_usage "$dst"

	i=0
	while [[ $i -lt ${#arr[@]} ]]; do
		l=${arr[$i]}
		((i++))
		totalb=$((totalb + _sfquota["${l}-blocks"]))
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
	echo >&2 "Total: ${totalb} blocks, $((totalb * 4 / 1024 / 1024 )) GB"

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
	local err

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

	lgstop "${lglid}" "$@" || err=255
	#_sf_lgrm "${lglid}" # Dont lgrm here and give user chance to explain to re-instate his server.

	_sf_deinit
	return "${err:-0}"
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

_lgshot() {
    local lg="${1:?}"
    local pid
	local geoip ip hn age_str t_created cip age_str_nc
	local data d
	local disp=()

    pid="$(docker inspect -f '{{.State.Pid}}' "${lg}")" || return
	{ [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ]; } && { echo >&2 "WARN: TG_TOKEN= and TG_CHATID= not set. Not sending screenshot"; return 0; }
	
	[ -e "${_sf_dbdir}/user/${lg}/token" ] && [ -z "$SF_FORCE" ] && {
		echo -e >&2 "${CDR}ERROR:${CN} ${lg} has a TOKEN and is likely a valued user. Set ${CDC}SF_FORCE=1${CN} to force-send screenshot."
		return
	}
	_sf_loaduserinfo "$lg"
	command -v xwd >/dev/null || { echo -e >&2 "ERROR: xwd not found. Try ${CDC}apt-get install x11-apps${CN}"; return 255; }
	command -v convert >/dev/null || { echo -e >&2 "ERROR: convert not found. Try ${CDC}apt-get install imagemagick${CN}"; return 255; }
	[ -n "$DISPLAY" ] && disp=("$DISPLAY")
	[ "${#disp[@]}" -eq 0 ] && disp=(":10" ":1" ":0")
	for d in "${disp[@]}"; do
		data="$(nsenter -n -t "${pid}" xwd -silent -root -display "${d:?}" 2>/dev/null | base64 -w0)"
		[ -n "$data" ] && break
	done
	[ -z "$data" ] && {
		echo -e >&2 "[$lg] No X11/VNC running. Not sending screenshot."
		return 250
	}

	echo "$data" | base64 -d | convert xwd:- "png:-" | curl -s -F "chat_id=${TG_CHATID}" -F caption="${t_created:-????-??-??} ${age_str_nc}"$'\n'"${lg} ${hn}"$'\n'"${ip} ${geoip}" -F "photo=@-" "https://api.telegram.org/bot${TG_TOKEN}/sendPhoto" >/dev/null
}

lgshot() {
	local ret
	_sf_init
	_lgshot "$@"
	ret="$?"
	_sf_deinit

	return "$ret"
}


_lgvnc() {
	local lg="${1:?}"
	local pid
	local disp=()
	local opts=()

	[ -e "${_sf_dbdir}/user/${lg}/token" ] && [ -z "$SF_FORCE" ] && {
		echo -e >&2 "${CDR}ERROR:${CN} ${lg} has a TOKEN and is likely a valued user. VNC is not permittted."
		return
	}
	command -v socat >/dev/null || { echo -e >&2 "${CDR}ERROR:${CN} Need ${CDC}socat${CN}"; return; }
	command -v x11vnc >/dev/null || { echo -e >&2 "${CDR}ERROR:${CN} Need ${CDC}x11vnc${CN}"; return; }
    pid="$(docker inspect -f '{{.State.Pid}}' "${lg}")" || return

	pidof socat-vnc >/dev/null || ( bash -c "exec -a socat-vnc socat TCP-LISTEN:5669,bind=127.0.0.1,reuseaddr,fork UNIX-CONNECT:'${_sf_shmdir}/run/.x11vnc'" &>/dev/null &)

	[ -n "$DISPLAY" ] && disp=("$DISPLAY")
	[ "${#disp[@]}" -eq 0 ] && disp=(:10 :20 :1 :0 :2 :3 :4 :5 :6 :7 :8 :9)
	# Allow to manipulate VNC sessions if SF_FORCE is set. Otherwise it's View-Only
	[ -z "$SF_FORCE" ] && { opts=("-viewonly"); echo -e "Use ${CDC}SF_FORCE=1${CN} to disable View-Only-Mode"; }
	echo -e "Use ${CDC}-L5669:127.0.0.1:5669${CN} to vnc to ${lg}. Press Ctrl-C to stop..."
	for d in "${disp[@]}"; do
		echo "Attempting $d"
		nsenter -n -i -t "${pid}" x11vnc -display "${d}" -shared -xkb -timeout 3600 -forever -norc -nopw "${opts[@]}" -unixsock "${_sf_shmdir}/run/.x11vnc" -noipv4 -nolookup -noipv6 -rfbport 0 -quiet 2>/dev/null && break
	done
	[ $? -ne 0 ] && echo -e >&2 "[${CDM}$lg${CN}] ${CDR}ERROR:${CN} No X11 running."
}

lgvnc() {
	local ret
	_sf_init
	_lgvnc "$@"
	ret="$?"
	_sf_deinit

	return "$ret"
}

lgls()
{
    # local IFS
	local arr

	_sf_init
    mapfile -t arr < <(_sfcg_forall)
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
	local IFS
	match=$1
	msg="$3"

	[[ "$2" == "stop" ]] && is_stop=1

	_sf_init
	stoparr=()
	mapfile -t arr < <(_sfcg_forall)
	for lglid in "${arr[@]}"; do
		_sfcg_psarr "$lglid" "$match" && continue

		_sfcfg_printlg "$lglid"
		if [[ -z $match ]]; then
			echo "$SF_G_PS"
		else
			echo "$SF_G_PS" | grep -E "${match:?}"'|$'
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
	local match="$1"
	local skip_token="$2"
    local IFS

	_sf_init
	[[ -z $match ]] && return

    mapfile -t arr < <(_sfcg_forall "$skip_token")
	for lglid in "${arr[@]}"; do
		_sfcg_psarr "$lglid" "$match" >/dev/null && continue
		echo "$lglid "
        _sfcfg_printlg "$lglid" >&2
	done

	_sf_deinit
}

lgxcall() {
	local arr
	local lglid
	local match="$1"
	local skip_token="$2"
	local cb_func="$3"
	shift 3

	[ -z "$cb_func" ] && { echo >&2 "ERROR: No callback function given"; return 255; }
    mapfile -t arr < <(_sfcg_forall "$skip_token")
	for lglid in "${arr[@]}"; do
		_sfcg_psarr "$lglid" "$match" >/dev/null && continue
		"${cb_func}" "$lglid" "$@"
	done
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
	# local IFS
	local -
	max="$1"
	is_stop="$2"
	[[ -z $max ]] && max=3
	set -o noglob
	# IFS=$'\n'
	mapfile -t real < <(pgrep docker-exec-sig -a | awk '{print $5;}')
	mapfile -t all < <(docker ps -f name=^lg- --format "table {{.Names}}")
	for x in "${all[@]}"; do
		[[ ! $x =~ ^lg- ]] && continue
		[[ "${real[*]}" =~ $x ]] && continue
		# check how many processes are running:
		mapfile -t arr < <(docker top "${x}" -o pid)
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

lgsh() { docker exec -w/root -u0 -e HISTFILE=/dev/null -it "$1" bash -c 'exec -a \[cached\] bash'; }

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

[ -z "$SF_NOINIT" ] && _sf_usage
# Might be sourced. Make $? to 0
: