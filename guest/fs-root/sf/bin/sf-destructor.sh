#! /bin/sh
# Use /bin/sh for smaller memory footprint

# Script to keep detached docker instance alive until all the user's
# processes have terminated (and all shells disconnected)

# Started from 'segfaultsh' via 'docker run' command.
# This runs inside the sf-guest context (e.g. no access to docker socket)

echo "Processes running: $(pgrep .|wc -l)"
SL_BIN_NAME="[SF-${SF_LID}] sleep"
SL_BIN="/dev/shm/${SL_BIN_NAME}"
ln -s /usr/bin/sleep "${SL_BIN}"
PATH="${PATH}:/dev/shm"
# Give user time to attach to a detached docker instance (docker exec)
"${SL_BIN_NAME}" 29 || sleep 29

while :; do
	n="$(pgrep .|wc -l)"
	# if 
	[ -z $n ] && break
	[ -n $SF_DEBUG ] && { echo "Running: $n"; ps --no-headers aux; }
	# init, destructor, wc, sub-shell
	[ "$n" -ge 5 ] || break # This also breaks if "$n" is bad.
	# If encfs died (/sec no longer a directory)
	[ -d /sec ] || break
	"${SL_BIN_NAME}" 30 || sleep 30 || break
	# exec -a "[sleep-${SF_LID}]" bash -c "sleep 30" --CANT USE. NOT BASH.
done
echo "sf-destructor.sh: DONE"

