#! /bin/sh
# Use /bin/sh for smaller memory footprint

# Script to keep detached docker instance alive until all the user's
# processes have terminated (and all shells disconnected)

# Started from 'segfaultsh' via 'docker run' command.
# This runs inside the sf-guest context (e.g. no access to docker socket)

echo "Processes running: $(pgrep .|wc -l)"
# Give user time to attach to a detached docker instance (docker exec)
sleep 29

while :; do
	n="$(pgrep .|wc -l)"
	[ -n $SF_DEBUG ] && { echo "Running: $n"; ps --no-headers aux; }
	# init, destructor, ps, wc, sub-shell
	[ "$n" -lt 5 ] && break
	# If encfs died (/sec no longer a directory)
	[ -d /sec ] || break
	sleep 30
	# exec -a "[sleep-${SF_LID}]" bash -c "sleep 30" --CANT USE. NOT BASH.
done
echo "sf-destructor.sh: DONE"

