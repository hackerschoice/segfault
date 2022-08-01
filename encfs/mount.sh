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

# Handle SIGTERM. Send TERM to encfs when docker-compose shuts down, unmount
# and exit.
_term()
{
	[[ -z $cpid ]] && exit
	kill "$cpid"
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
# NgingX is a good example. Thus Nginx needs to check unti IS-ENCRYPTED.TXT
# appears and exit otherwise.
sf_server()
{
	sf_server_init

	echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >/encfs/sec/IS-NOT-ENCRYPTED.txt
	encfs --standard -o nonempty -o allow_other -f --extpass="echo \"${ENCFS_SERVER_PASS}\"" "/encfs/raw" "/encfs/sec" -- -o noexec,noatime &
	cpid=$!

	# Give it 5 seconds and check if it is encrypted.
	sleep 5
	[[ ! -e /encfs/sec/IS-NOT-ENCRYPTED.txt ]] && {
		# We are encrypted!
		touch /encfs/sec/IS-ENCRYPTED.txt
		wait $cpid # SIGTERM will wake us
	}
	# SIGTERM or wrong SF_SEED
	echo -e "${CR}[$cpid] EncFS EXITED with $?..."

	fusermount -zu /encfs/sec
	exit 0
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
[[ "$1" = "server" ]] && sf_server

RAWDIR="/encfs/raw/user-${LID}"
SECDIR="/encfs/sec/user-${LID}" # typically on host: /dev/shm/encfs-sec/user-${LID}
[[ -d "${RAWDIR}" ]] || mkdir -p "${RAWDIR}" 2>/dev/null
[[ -d "${SECDIR}" ]] || mkdir -p "${SECDIR}" 2>/dev/null

[[ -n $MARKFILE ]] && check_markfile

echo "THIS-IS-NOT-ENCRYPTED *** DO NOT USE *** " >"${SECDIR}/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt"

PASSFILE="/dev/shm/pass-${LID}.txt"
echo "${LENCFS_PASS}" >"${PASSFILE}"
bash -c "exec -a '[encfs-${LID}]' encfs --standard --public -o nonempty -o allow_other -S \"${RAWDIR}\" \"${SECDIR}\" <\"${PASSFILE}\""
rm -f "${PASSFILE:?}"
# encfs --standard --public -o nonempty -o allow_other --extpass="echo \"${LENCFS_PASS}\"" "${RAWDIR}" "${SECDIR}"

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
# fusermount -zuq "${SECDIR}" || echo "fusermount: Error ($?)"
fusermount -zu "${SECDIR}" || echo "fusermount: Error ($?)"
rmdir "${SECDIR:-/dev/null/BAD}" 2>/dev/null
echo "DONE"
