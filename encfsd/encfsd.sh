#! /bin/bash

source /sf/bin/funcs.sh
source /sf/bin/funcs_redis.sh

MARK_FN="THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"

BAD()
{
	local delay
	delay="$1"

	shift 1
	echo -e >&2 "[${CR}BAD${CN}] $*"
	sleep "$delay"
}

do_exit_err()
{
	# Kill the redis-loop
	[[ -z $CPID ]] && { kill $CPID; unset CPID; }

	killall encfs # This will unmount
	ERREXIT "$1" "Exiting main thread"
}

xmkdir()
{
	[[ -z $1 ]] && return 255
	[[ -d "$1" ]] && return 0
	mkdir "$1"
}

# [name] [secdir] [rawdir]
# Return 1 when already mounted.
encfs_mkdir()
{
	local name
	local secdir
	local rawdir

	name="$1"
	secdir="$2"
	rawdir="$3"

	xmkdir "${rawdir}" || return 255

	if [[ -d "${secdir}" ]]; then
		mountpoint "${secdir}" >/dev/null && {
			# echo "[encfs-${name}] Already mounted."
			[[ ! -e "${secdir}/${MARK_FN}" ]] && return 1
			ERR "[encfs-${name}] Mounted but markfile exist showing not encrypted."
			return 255
		}
		return 0
	fi

	# HERE: $secdir does _NOT_ exist.

	# If EncFS died then a stale mount point might still exist.
	# -d/-e/-f all fail (Transport endpoint is not connected)
	# Force an unmount if it's not a directory (it's 'stale').
	fusermount -zu "${secdir}" 2>/dev/null	
	xmkdir "${secdir}" || return 255
}

# [name] [SECRET] [SECDIR] [RAWDIR] [noatime,noexec] [info]
encfs_mount()
{
	local name
	local s
	local err
	local secdir
	local rawdir
	local opts
	local info
	name="$1"
	s="$2"
	secdir="$3"
	rawdir="$4"
	opts="$5"
	info="$6"

	[[ ! -e "${secdir}/${MARK_FN}" ]] && { echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >"${secdir}/${MARK_FN}" || { BAD 0 "Could not create Markfile"; return 255; } }

	# local cpid
	LOG "${name}" "Mounting ${info}"
	# echo "$s" | bash -c "exec -a '[encfs-${name:-BAD}]' encfs --standard --public -o nonempty -S \"${rawdir}\" \"${secdir}\" -- -o fsname=/dev/sec-\"${name}\" -o \"${opts}\"" >/dev/null
	# --nocache -> Blindly hoping that encfs consumes less memory?!
	# -s single thread. Seems to give better I/O performance and uses less memory (!)
	ERRSTR=$(echo "$s" | nice -n10 bash -c "exec -a '[encfs-${name:-BAD}]' encfs -s --nocache --standard --public -o nonempty -S \"${rawdir}\" \"${secdir}\" -- -o \"${opts}\"")
	ret=$?
	[[ $ret -eq 0 ]] && return 0

	ERR "[encfs-${name}] failed"
	return 255
}

# [name]
encfs_mount_server()
{
	local secdir
	local secret
	local name
	secdir="/encfs/sec/${1}-root"
	rawdir="/encfs/raw/${1}-root"
	name="$1"
	secret="$2"

	encfs_mkdir "${name}" "${secdir}" "${rawdir}" || return

	# We use a file as a semaphore so that we dont need to give
	# the waiting container access to redis.
	[[ -f "${secdir}/.IS-ENCRYPTED" ]] && rm -f "${secdir}/.IS-ENCRYPTED"	
	# Note: Use SLEEPEXIT to give sf-destructor enough time to start (and aquire `pid: "service:sf-encfsd"`)
	# so that sf-encfs has enough time to report the error (likely cause is bad SF_SEED=)
	encfs_mount "${name}" "${secret}" "${secdir}" "${rawdir}" "noexec,noatime" || SLEEPEXIT 254 15 "EncFS ${name}-root failed '${ERRSTR}."
	touch "${secdir}/.IS-ENCRYPTED"

	[[ ! -d "${secdir}/${name}" ]] && mkdir "${secdir}/${name}"
}

# [LID]
load_limits()
{
	local lid
	lid="$1"

	unset SF_USER_FS_SIZE
	unset SF_USER_FS_INODE
	unset SF_USER_ROOT_FS_SIZE
	unset SF_USER_ROOT_FS_INODE
	
	# First source global	
	[[ -f "/config/etc/sf/sf.conf" ]] && eval "$(grep ^SF_ "/config/etc/sf/sf.conf")"

	# Then source user specific limits
	[[ -f "/config/db/user/lg-${lid}/limits.conf" ]] && eval "$(grep ^SF_ "/config/db/user/lg-${lid}/limits.conf")"
}

dir2prjid()
{
	local dir
	local p
	dir="$1"

	p=$(lsattr -dp "${dir}")
	p=${p%% --*}
	echo "${p##* }"
}

# Set XFS quota on sub folders. This normally only needs to be done
# when the subfolder is created.
# Note: Set XFS-QUOTA _every time_ just in case we restored from backup
#
# XFS quota on subfolders inside an encfs are tricky:
# - xfs_quota only works on the underlaying encfs raw data (encrypted)
# - We do not know the directory name (inside /raw) because it's encrypted (!)
# - Instead use a trick:
#   1. Create the directory.
#   2. Search for identical inode in RAWDIR
xfs_quota_sub()
{
	local prjid
	local base_rawdir
	local secdir
	local rawdir
	local err
	prjid="$1"
	base_rawdir="$2"
	secdir="$3"

	if [[ ! -d "${secdir}" ]]; then
		mkdir "${secdir}"
		# Dont leak when directory was created as this is also the user's login time.
		touch -t 197001011200 "${secdir}"
	fi

	# Find the RAWDIR (it has the same inode; inode is passed through by EncFS)
	inode=$(stat -c %i "${secdir}")
	rawdir=$(find "${base_rawdir}" -maxdepth 1 -type d -inum "$inode")
	[[ -z "${rawdir}" ]] || [[ ! -d "${rawdir}" ]] && { ERR "XFS rawdir not found"; return; }

	local prjid_old
	prjid_old=$(dir2prjid "${rawdir}")
	[[ "$prjid_old" != "$prjid" ]] && {
		err=$(xfs_quota -x -c "project -s -p ${rawdir} ${prjid}" 2>&1) || { ERR "XFS Quota /everyone: \n'$err'"; }
	}
}


# [LID] [SECRET]
cmd_user_mount()
{
	local lid
	local secret
	local rawdir
	local secdir
	local prjid
	lid="$1"
	secret="${2//[^[:alnum:]]/}"

	[[ ${#secret} -ne 24 ]] && { BAD 0 "Bad secret='$secret'"; return 255; }

	secdir="/encfs/sec/lg-${lid}"
	rawdir="/encfs/raw/user/lg-${lid}"
	encfs_mkdir "${lid}" "${secdir}" "${rawdir}"
	ret=$?
	[[ $ret -eq 1 ]] && return 0 # Already mounted
	[[ $ret -ne 0 ]] && return 255

	# HERE: Not yet mounted.
	# Set XFS limits
	load_limits "${lid}"
	[[ -n $SF_USER_FS_INODE ]] || [[ -n $SF_USER_FS_SIZE ]] && {
		SF_NUM=$(<"/config/db/user/lg-${lid}/num") || return 255
		SF_HOSTNAME=$(<"/config/db/user/lg-${lid}/hostname") || return 255
		prjid=$((SF_NUM + 10000000))
		DEBUGF "SF_NUM=${SF_NUM}, prjid=${prjid}, SF_HOSTNAME=${SF_HOSTNAME}, INODE=${SF_USER_FS_INODE}, SIZE=${SF_USER_FS_SIZE}"
		err=$(xfs_quota -x -c "limit -p ihard=${SF_USER_FS_INODE:-16384} bhard=${SF_USER_FS_SIZE:-128m} ${prjid}" 2>&1) || { ERR "XFS-QUOTA: \n'$err'"; return 255; }
		# Only set it if it isnt already set (this can take very long to complete)
		local prjid_old
		prjid_old=$(dir2prjid "${rawdir}")
		[[ "$prjid_old" != "$prjid" ]] && {
			DEBUGF "Creating new prjid=$prjid, old $prjid_old"
			err=$(xfs_quota -x -c "project -s -p ${rawdir} ${prjid}" 2>&1) || { ERR "XFS-QUOTA /sec: \n'$err'"; return 255; }
		} 
	}

	# Mount if not already mounted. Continue on error (let client hang)
	encfs_mount "${lid}" "${secret}" "${secdir}" "${rawdir}" "noatime" "/sec (INODE_MAX=${SF_USER_FS_INODE}, BYTES_MAX=${SF_USER_FS_SIZE})" || return 255

	# Extend same project quota to /onion and /everyone/SF_HOSTNAME
	[[ -n $prjid ]] && {
		xfs_quota_sub "${prjid}" "${BASE_RAWDIR_WWW}" "/encfs/sec/www-root/www/${SF_HOSTNAME,,}" 
		xfs_quota_sub "${prjid}" "${BASE_RAWDIR_EVR}" "/encfs/sec/everyone-root/everyone/${SF_HOSTNAME}" 
	}

	# Mark as mounted (for destructor to track)
	touch "/sf/run/encfsd/user/lg-${lid}"
	return 0
}

# Set ROOT_FS xfs quota and move encfs to lg's cgroup
# [LID] "[CID] [INODE LIMIT] [relative OVERLAY2 dir]"
cmd_setup_encfsd()
{
	local lid
	local ilimit
	local dir
	local prjid
	local cid
	local pid
	local str
	local err
	local cg_fn
	lid="$1"
	cid=${2%% *}
	str=${2#* }
	ilimit=${str%% *}
	ilimit=${ilimit//[^0-9]/}
	dir="/var/lib/docker/overlay2/${str#* }"

	# Move lg's encfsd to lg's cgroup.
	# Note: We can not use cgexec because encfsd needs to be started before the lg container
	# is started. Thus we only know the LG's container-ID _after_ encfsd has started.
	pid=$(pgrep "^\[encfs-${lid}")
	unset err
	cg_fn="system.slice/containerd.service/sf.slice/sf-guest.slice/${cid}/tasks"
	if [[ -e "/sys/fs/cgroup/cpu/${cg_fn}" ]]; then
		## CGROUPv1
		# It's really really bad to use cgroup/unified if /sys/fs/cgroup is cgroup-v1:
		# It messses up /proc/<PID>/cgroup and nobody really knows the effect of this.

		# Note: The 'pid' is local to this namespace. However, linux kernel still accepts
		# it for moving between cgroups (but will yield an error).
		echo "$pid" >"/sys/fs/cgroup/cpu/${cg_fn}" 2>/dev/null || err=1
		echo "$pid" >"/sys/fs/cgroup/blkio/${cg_fn}" 2>/dev/null || err=1
	else
		## CGROUPv2
		cg_fn="/sys/fs/cgroup/sf.slice/sf-guest.slice"
		str="${cid}"
		cg_fn="/sys/fs/cgroup/sf.slice/sf-guest.slice/docker-${cid}.scope/cgroup.procs"
		[[ ! -e "${cg_fn}" ]] && cg_fn="/sys/fs/cgroup/sf.slice/sf-guest.slice/${cid}/cgroup.procs"
		echo "$pid" >"${cg_fn}" || err=1
	fi
	grep -F sf-guest.slice "/proc/${pid}/cgroup" &>/dev/null || BAD 0 "Could not move encfs[pid=$pid] to lg's cgroup[cid=$cid]"

	[[ -z $ilimit ]] && { BAD 0 "ilimit is empty"; return 255; }
	[[ $ilimit -le 0 ]] && return 0

	# Setup LG's Root-FS inode limit 		

	[[ ! -d "${dir}" ]] && { BAD 0 "Not found: ${dir}."; return 255; }
	s=$(lsattr -dp "${dir}")
	prjid=${s%% --*}
	prjid=${prjid##* }  # trim leading white spaces
	[[ -z $prjid ]] || [[ $prjid -eq 0 ]] && { BAD 0 "Invalid prjid='$prjid'"; return 255; }

	xfs_quota -x -c "limit -p ihard=${ilimit} $prjid" || { BAD 0 "XFS_QUOTA filed"; return 255; }
}

# Note: Started as background process.
redis_loop_forever()
{
	local secdir
	local cmd
	local lid
	local reqid
	local n_conn_err

	while :; do
		res=$(redr BLPOP encfs 0) || {
			((n_conn_err++))
			[[ $n_conn_err -gt 180 ]] && ERREXIT 250 "Giving up..."
			WARN "Waiting for Redis..."
			sleep 1
			continue
		}
		unset n_conn_err

		[[ -z $res ]] && {
			# HERE: no result
			WARN "Redis: Empty results."
			sleep 1
			continue
		}

		# Remove all but last line
		res="${res##*$'\n'}"

		# [REQID] [LID] [CMD] [ARGS]
		reqid=${res%% *}
		reqid=${reqid//[^0-9]/}
		res=${res#* }

		lid="${res:0:10}"  # the LID 
		lid="${lid//[^[:alnum:]]/}"
		[[ ${#lid} -ne 10 ]] && { BAD 0 "Bad lid='$lid'"; continue; }
		res=${res:11}

		cmd=${res:0:1}
		res=${res:2}

		if [[ "$cmd" == "X" ]]; then
			cmd_setup_encfsd "${lid}" "${res}" || continue
		elif [[ "$cmd" == "M" ]]; then
			cmd_user_mount "${lid}" "${res}" || continue
		else
			continue
		fi

		# ALL OK
		red RPUSH "encfs-${reqid}-${lid}-${cmd}" "OK" >/dev/null
	done
}

_trap() { :; }
# Install an empty signal handler so that 'wait()' (below) returns
trap _trap SIGTERM
trap _trap SIGINT

[[ -z $SF_SEED ]] && ERREXIT 255 "SF_SEED= not set"
[[ -z $SF_REDIS_AUTH ]] && ERREXIT 255 "SF_REDIS_AUTH= not set"

ENCFS_SERVER_PASS=$(echo -n "EncFS-SERVER-PASS-${SF_SEED}" | sha512sum | base64)
ENCFS_SERVER_PASS="${ENCFS_SERVER_PASS//[^[:alpha:]]}"
ENCFS_SERVER_PASS="${ENCFS_SERVER_PASS:0:24}"

export REDISCLI_AUTH="${SF_REDIS_AUTH}"

# Mount Segfault-wide encrypted file systems
encfs_mount_server "everyone" "${ENCFS_SERVER_PASS}"
# Create mountpoint for guest's /everyone/this
[[ ! -d "/encfs/sec/everyone-root/everyone/this" ]] && mkdir "/encfs/sec/everyone-root/everyone/this"
cp "/config/etc/sf/WARNING---SHARED-BETWEEN-ALL-SERVERS---README.txt" "/encfs/sec/everyone-root/everyone"
encfs_mount_server "www" "${ENCFS_SERVER_PASS}"

BASE_RAWDIR_WWW=$(find /encfs/raw/www-root/      -maxdepth 1 -type d -inum "$(stat -c %i /encfs/sec/www-root/www)")
BASE_RAWDIR_EVR=$(find /encfs/raw/everyone-root  -maxdepth 1 -type d -inum "$(stat -c %i /encfs/sec/everyone-root/everyone)")

[[ ! -d "${BASE_RAWDIR_WWW:?}" ]] && ERREXIT 255 "Cant find encrypted /encfs/raw/www-root/*"
[[ ! -d "${BASE_RAWDIR_EVR:?}" ]] && ERREXIT 255 "Cant find encrypted /encfs/raw/everyone-root/*"

# sleep infinity
# Need to start redis-loop in the background. This way the foreground bash
# will still be able to receive SIGTERM.
redis_loop_forever &
CPID=$!
wait $CPID # SIGTERM will wake us
# HERE: Could be a SIGTERM or a legitimate exit by redis_loop process
do_exit_err $?
