#! /bin/bash

source /sf/bin/funcs.sh

MARK_FN="THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"

BAD()
{
	local delay
	delay="$1"

	shift 1
	echo -e >&2 "[BAD] $*"
	sleep "$delay"
}

do_exit_err()
{
	# Kill the redis-loop
	[[ -z $CPID ]] && { kill $CPID; unset CPID; }

	killall encfs # This will unmount
	exit "$1"
}

xmkdir()
{
	[[ -d "$1" ]] && return
	mkdir "$1"
}

# [name] [secdir] [rawdir]
encfs_mkdir()
{
	local name
	local secdir
	name="$1"
	secdir="$2"

	[[ -d "${secdir}" ]] && mountpoint "${secdir}" >/dev/null && {
		echo "[encfs-${name}] Already mounted."
		[[ ! -e "${secdir}/${MARK_FN}" ]] && return 0
		ERR "[encfs-${name}] Mounted but markfile exist showing not encrypted."
		return 255
	}

	# If EncFS died then a stale mount point might still exist.
	# -d/-e/-f all fail (Transport endpoint is not connected)
	# Force an unmount if it's not a directory (it's 'stale').
	fusermount -zu "${secdir}" 2>/dev/null && [[ -d "${secdir}" ]] && return
	[[ ! -d "${secdir}" ]] && fusermount -zu "${secdir}" 2>/dev/null

	xmkdir "${secdir}" || return 255
	xmkdir "${rawdir}" || return 255
}

# [name] [SECRET] [SECDIR] [RAWDIR] [noatime,noexec] [info]
encfs_mount()
{
	local name
	local s
	local n
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

	# is_tracked "${l}" && return 0 # Already mounted. Success.

	[[ ! -e "${secdir}/${MARK_FN}" ]] && { echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >"${secdir}/${MARK_FN}" || { BAD 0 "Could not create Markfile"; return 255; } }

	# local cpid
	LOG "${name}" "Mounting ${info}"
	# echo "$s" | bash -c "exec -a '[encfs-${name:-BAD}]' encfs --standard --public -o nonempty -S \"${rawdir}\" \"${secdir}\" -- -o fsname=/dev/sec-\"${name}\" -o \"${opts}\"" >/dev/null
	# --nocache -> Blindly hoping that encfs consumes less memory?!
	echo "$s" | bash -c "exec -a '[encfs-${name:-BAD}]' encfs --nocache --standard --public -o nonempty -S \"${rawdir}\" \"${secdir}\" -- -o \"${opts}\"" >/dev/null
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
	encfs_mount "${name}" "${secret}" "${secdir}" "${rawdir}" "noexec,noatime" || ERREXIT 254 "EncFS ${name}-root failed."
	touch "${secdir}/.IS-ENCRYPTED"

	# redis-cli -h sf-redis SET "encfs-ts-${name}" "$(date +%s)"
}

# [LID]
load_limits()
{
	local lid
	lid="$1"

	# First source global	
	[[ -f "/config/etc/sf/sf.conf" ]] && eval "$(grep ^SF_ "/config/etc/sf/sf.conf")"

	# Then source user specific limits
	[[ -f "/config/db/db-${lid}/limits.conf" ]] && eval "$(grep ^SF_ "/config/db/db-${lid}/limits.conf")"
}

redis_loop_forever()
{
	local secdir

	while :; do
		res=$(redis-cli -h sf-redis BLPOP encfs 0) || ERREXIT 250 "Failed with $?"

		[[ -z $res ]] && {
			# HERE: no result
			WARN "Redis: Empty results."
			sleep 1
			continue
		}

		# DEBUGF "RES='$res'"
		# Remove key (all but last line)
		res="${res##*$'\n'}"
		# [LID] [SECRET] [REQID]
		name="${res:0:10}"  # the LID 
		name="${name//[^[:alnum:]]/}"
		secret="${res:11:24}"
		secret="${secret//[^[:alnum:]]/}"
		reqid="${res:36}"
		reqid="${reqid//[^[:alnum:]]/}"

		[[ ${#secret} -ne 24 || ${#name} -ne 10 ]] && { BAD 0 "Bad secret='$secret'/name='$name'"; continue; }

		secdir="/encfs/sec/user-${name}"
		rawdir="/encfs/raw/user/user-${name}"
		encfs_mkdir "${name}" "${secdir}" "${rawdir}" || return

		# Set up XFS limits
		# xfs_quota -x -c 'limit -p ihard=80 Alice' "${SF_DATADEV}"
		load_limits "${name}"
		[[ -n $SF_USER_FS_INODE_MAX ]] && [[ -n $SF_USER_FS_BYTES_MAX ]] && {
			SF_NUM=$(<"/config/db/db-${name}/num") || continue
			SF_HOSTNAME=$(<"/config/db/db-${name}/hostname") || continue
			prjid=$((SF_NUM + 10000000))
			# DEBUGF "SF_NUM=${SF_NUM}, prjid=${prjid}, SF_HOSTNAME=${SF_HOSTNAME}, INODE_MAX=${SF_USER_FS_INODE_MAX}, BYTES_MAX=${SF_USER_FS_BYTES_MAX}"
			err=$(xfs_quota -x -c "limit -p ihard=${SF_USER_FS_INODE_MAX} bhard=${SF_USER_FS_BYTES_MAX} ${prjid}" "${SF_DATADEV}" 2>&1) || { ERR "XFS-QUOTA: \n'$err'"; continue; }
			err=$(xfs_quota -x -c "project -s -p ${rawdir} ${prjid}" "${SF_DATADEV}" 2>&1) || { ERR "XFS-QUOTA /sec: \n'$err'"; continue; }
		}

		# Mount if not already mounted. Continue on error (let client hang)
		encfs_mount "${name}" "${secret}" "${secdir}" "${rawdir}" "noatime" "/sec (INODE_MAX=${SF_USER_FS_INODE_MAX}, BYTES_MAX=${SF_USER_FS_BYTES_MAX})" || continue

		# XFS limit for /onion must be set up after mounting.
		# Finding out the WWW path is ghetto:
		# - xfs_quota can only work on the underlaying encfs structure.
		#   That however is enrypted and we do not know the directory name
		# - Use last created directory.
		[[ ! -d "/encfs/sec/www-root/www/${SF_HOSTNAME,,}" ]] && {
			xmkdir "/encfs/sec/www-root/www/${SF_HOSTNAME,,}"
			USER_RAWDIR=$(find "${BASE_RAWDIR}" -type d -maxdepth 1 -print | tail -n1)
			[[ ! -d "${USER_RAWDIR:?}" ]] && continue
			err=$(xfs_quota -x -c "project -s -p ${USER_RAWDIR} ${prjid}" "${SF_DATADEV}" 2>&1) || { ERR "XFS Quota /onion: \n'$err'"; continue; }
		}

		# Success. Tell the guest that EncFS is ready (newly mounted or was mounted)
		# prints "1" to stdout.
		redis-cli -h sf-redis RPUSH "encfs-${name}-${reqid}" "OK" >/dev/null
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
encfs_mount_server "www" "${ENCFS_SERVER_PASS}"

BASE_RAWDIR=$(find /encfs/raw/www-root/ -type d -maxdepth 1 -print | tail -n1)

[[ ! -d "${BASE_RAWDIR:?}" ]] && ERREXIT 255 "Cant find encrypted /encfs/raw/www-root/*"

# sleep infinity
# Need to start redis-loop in the background. This way the foreground bash
# will still be able to receive SIGTERM.
redis_loop_forever &
CPID=$!
wait $CPID # SIGTERM will wake us
# HERE: Could be a SIGTERM or a legitimate exit by redis_loop process
do_exit_err $?




