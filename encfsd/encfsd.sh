#! /bin/bash

source /sf/bin/funcs.sh

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
	# Odd occasion when no EncFS is running but kernel still has a stale mountpoint
	# mountpoint: everyone-root: Transport endpoint is not connected
	fusermount -zu "$1" 2>/dev/null
	mkdir "$1"
}

# [name] [SECRET] [SECDIR] [RAWDIR] [noatime,noexec]
encfs_mount()
{
	local name
	local s
	local n
	local err
	local secdir
	local rawdir
	local opts
	name="$1"
	s="$2"
	secdir="$3"
	rawdir="$4"
	opts="$5"

	# is_tracked "${l}" && return 0 # Already mounted. Success.

	local markfile
	markfile="${secdir}/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"

	[[ -d "${secdir}" ]] && mountpoint "${secdir}" >/dev/null && {
		echo "[encfs-${name}] Already mounted."
		[[ ! -e "${markfile}" ]] && return 0
		ERR "[encfs-${name}] Mounted but markfile exist showing not encrypted."
		return 255
	}

	xmkdir "${secdir}" || return 255
	xmkdir "${rawdir}" || return 255

	[[ ! -e "${markfile}" ]] && { echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >"${markfile}" || { BAD 0 "Could not create Markfile"; return 255; } }

	# local cpid
	LOG "${name}" "Mounting ${secdir} to ${rawdir}."
	echo "$s" | bash -c "exec -a '[encfs-${name:-BAD}]' encfs    --standard --public -o nonempty -S \"${rawdir}\" \"${secdir}\" -- -o "${opts}"" &>/dev/null
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
	name="$1"
	secret="$2"

	# We use a file as a semaphore so that we dont need to give
	# the waiting container access to redis.
	[[ -f "${secdir}/.IS-ENCRYPTED" ]] && rm -f "${secdir}/.IS-ENCRYPTED"	
	encfs_mount "${name}" "${secret}" "${secdir}" "/encfs/raw/${name}-root" "noexec,noatime" || ERREXIT 254 "EncFS ${name}-root failed."

	# redis-cli -h sf-redis SET "encfs-ts-${name}" "$(date +%s)"
}

redis_loop_forever()
{
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

		# Mount if not already mounted. Continue on error (let client hang)
		encfs_mount "${name}" "${secret}" "/encfs/sec/user-${name}" "/encfs/raw/user/user-${name}" "noatime" || continue

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

# Need to start redis-loop in the background. This way the foreground bash
# will still be able to receive SIGTERM.
redis_loop_forever &
CPID=$!
wait $CPID # SIGTERM will wake us
# HERE: Could be a SIGTERM or a legitimate exit by redis_loop process
do_exit_err $?




