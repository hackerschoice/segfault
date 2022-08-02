#! /bin/bash

# Create an Encrypted FUSE drive. 
# Called by:
#    segfault.sh    - data/user/user-* for the user's /sec. Password derived from
#                     user's SECRET
#    server         - data/onion-www for system wide /onion. Same password per
#                     deployment.
# CY="\e[1;33m" # yellow
CR="\e[1;31m" # red
# CC="\e[1;36m" # cyan
# CN="\e[0m"    # none

do_exit()
{
	fusermount -zu /sec
	[[ -n $cpid ]] && kill "$cpid" # This will unmount
	unset cpid
	[[ -n "$PASSFILE" ]] && [[ -e "$PASSFILE" ]] && rm -rf "${PASSFILE:?}"
	exit "$1"
}

# Handle SIGTERM. Send TERM to encfs when docker-compose shuts down, unmount
# and exit.
_term()
{
	do_exit 0
}

create_load_seed()
{
	[[ -n $SF_SEED ]] && return
	[[ ! -f "/config/etc/seed/seed.txt" ]] && {
		head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32 >/config/etc/seed/seed.txt || { echo >&2 "Can't create \${SF_BASEDIR}/config/etc/seed/seed.txt"; exit 255; }
	}
	SF_SEED="$(cat /config/etc/seed/seed.txt)"
	[[ -z $SF_SEED ]] && { echo -e >&2 "mount.sh: Failed to generated SF_SEED="; exit 254; }
}


sf_server_init()
{
	trap _term SIGTERM

	create_load_seed

	ENCFS_SERVER_PASS=$(echo -n "EncFS-SERVER-PASS-${SF_SEED}" | sha512sum | base64 | tr -dc '[:alpha:]' | head -c 24)
}


# The server needs to be initialized differently. All instances are started
# from docker compose. Some are started before EncFS can mount the directory.
# NgingX is a good example. Thus Nginx needs to check until .ENCRYPTED.TXT
# appears and exit otherwise.
# We must start EncFS as a child so that we can use 'wait $cpid' or otherwise
# we dont get the SIGTERM when the intance shuts down (sleep does not get it)
# and encfs would get a SIGKILL (e.g. thus not able to unmount /sec)
sf_server()
{
	sf_server_init

	[[ -f /sec/.IS-ENCRYPTED ]] && rm -f /sec/.IS-ENCRYPTED
	echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >/sec/IS-NOT-ENCRYPTED.txt || { echo "Could not create Markfile"; exit 138; }

	PASSFILE="/dev/shm/pass.txt"
	echo "${ENCFS_SERVER_PASS}" >"${PASSFILE}"
	bash -c "exec -a '[encfs-${2:-BAD}]' encfs -f --standard --public -o nonempty -S \"/raw\" \"/sec\" -- -o noexec,noatime" <"${PASSFILE}" &
	cpid=$!

	# Wait until /sec is mounted. Then mark directories with .IS-ENCRYPTED
	while :; do
		[[ ! -e /sec/IS-NOT-ENCRYPTED.txt ]] && break
		kill -0 $cpid || do_exit 128 # bash or EncFS died
		sleep 0.5
	done

	# We must delete PASSFILE _after_ mounting is complete.
	# Otherwise 'bash' starts in the background (but before it calls EncFS) and the current (parent)
	# bash would delete the filename 
	rm -f "${PASSFILE:?}"

	[[ -n $2 ]] && [[ ! -d "/sec/${2}" ]] && mkdir "/sec/${2}"

	touch /sec/.IS-ENCRYPTED

	wait $cpid # SIGTERM will wake us
	echo -e "${CR}[$cpid] EncFS EXITED with $?..."
	do_exit 0 # exit with 0: Do not restart.

	# BusyBox cant use custom process name for 'sleep':
	# exec -a [sleep-1234] sleep infinity => applet not found
	# bash executes 'sleep' (symlink to /bin/busybox) with with argv[0] == [sleep-1234]
	# Dont use 'exec'. SIGTERM needs to return to this bash so we can
	# terminate encfs.
}

# Wait until MARKFILE (on /sec cleartext) has disappeared.
check_markfile()
{
	n=0

	[[ -n $SF_DEBUG ]] && echo "DEBUG: Checking for '${SECDIR}/${MARKFILE}'"

	while [[ -f "${SECDIR}/${MARKFILE}" ]]; do
		[[ -n $SF_DEBUG ]] && echo "DEBUG: Round #${n}"
		if [[ $n -gt 0 ]]; then sleep 0.5; else sleep 0.1; fi
		n=$((n+1))
		[[ $n -gt 10 ]] && exit 253 # "Could not create /sec..."
	done

	exit 0 # /sec created
}

# For the 'server'
[[ "$1" = "server" ]] && sf_server "$@"

RAWDIR="/encfs/raw/user-${LID}"
# SECDIR="/encfs/sec/user-${LID}" # typically on host: /dev/shm/encfs-sec/user-${LID}
SECDIR="/encfs/sec/" # typically on host: /dev/shm/encfs-sec/user-${LID}
[[ -d "${RAWDIR}" ]] || mkdir -p "${RAWDIR}" 2>/dev/null
[[ -d "${SECDIR}" ]] || mkdir -p "${SECDIR}" 2>/dev/null

[[ -n $MARKFILE ]] && check_markfile

echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >"${SECDIR}/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"

PASSFILE="/dev/shm/pass-${LID}.txt"
echo "${LENCFS_PASS}" >"${PASSFILE}"
bash -c "exec -a '[encfs-${LID}]' encfs --standard --public -o nonempty -S \"${RAWDIR}\" \"${SECDIR}\" <\"${PASSFILE}\""
ret=$?
rm -f "${PASSFILE:?}"
[[ $ret -ne 0 ]] && exit 124

# Give segfaultsh time to start guest shell instance
sleep 5
# Monitor: Unmount when user instance is no longer running.
while :; do
	docker container inspect "lg-${LID}" -f '{{.State.Status}}' || break
	# Break if EncFS died
	pgrep encfs || break
	sleep 10
done

echo "Unmounting lg-${LID} [${SECDIR}]"
fusermount -zu "${SECDIR}" || echo "fusermount: Error ($?)"
rmdir "${SECDIR:-/dev/null/BAD}" 2>/dev/null
echo "DONE"
