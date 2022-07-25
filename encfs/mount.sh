#! /bin/bash

# Create an Encrypted FUSE drive. 
# Called by:
#    segfault.sh    - data/user/user-* for the user's /sec. Password derived from
#                     user's SECRET
#    server         - data/onion-www for system wide /onion. Same password per
#                     deployment.
CY="\033[1;33m" # yellow
CR="\033[1;31m" # red
CC="\033[1;36m" # cyan
CN="\033[0m"    # none

# Handle SIGTERM. Send TERM to encfs when docker-compose shuts down, unmount
# and exit.
_term()
{
	[[ -z $cpid ]] && return
	kill "$cpid"
}

sf_server_init()
{
	trap _term SIGTERM

	[[ -z $SF_ENCFS_PASS ]] && {
		[[ -e "/config/encfs.pass" ]] || {
			echo -e "${CR}Not found: config/etc/encfs/encfs.pass${CN}
--> Try ${CC}head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32 >config/etc/encfs/encfs.pass${CN}"
			sleep 5
			exit 255
		}
		SF_ENCFS_PASS="$(cat /config/encfs.pass)"
		[[ -z $SF_ENCFS_PASS ]] && { echo "SF_ENCFS_PASS is EMPTY"; sleep 5; exit 254; }
	}
}

sf_server()
{
	sf_server_init

	encfs --standard -o nonempty -o allow_other -f --extpass="echo \"${SF_ENCFS_PASS}\"" "/encfs/raw" "/encfs/sec" &
	cpid=$!
	wait $cpid # SIGTERM will wake us

	fusermount -zu /encfs/sec
	exit 0
}

# Wait until MARKFILE (on /sec cleartext) has disappeared.
check_markfile()
{
	n=0
	while [[ -f "${SECDIR}/${MARKFILE}" ]]; do
		[[ -n $SF_DEBUG ]] && echo "DEBUG: Round #${n}"
		if [[ $n -gt 0 ]]; then sleep 2; else sleep 0.1; fi
		n=$((n+1))
		[[ $n -gt 5 ]] && exit 253 # "Could not create /sec..."
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

encfs --standard -o nonempty -o allow_other --extpass="echo \"${LENCFS_PASS}\"" "${RAWDIR}" "${SECDIR}"

# Monitor: Unmount when user instance is no longer running.
sleep 5
while :; do
	docker container inspect "lg-${LID}" -f '{{.State.Status}}' || break
	# Break if EncFS died
	ps -o comm | grep encfs || break
	sleep 10
done

echo "Unmounting lg-${LID} [${SECDIR}]"
# fusermount -zuq "${SECDIR}" || echo "fusermount: Error ($?)"
fusermount -zu "${SECDIR}" || echo "fusermount: Error ($?)"
rmdir "${SECDIR:-/dev/null/BAD}" 2>/dev/null
echo "DONE"
