#! /bin/bash

# EXIT unless "$2" exists.
#
# This is used by Nginx and sf-host to wait until EncFS
# has fully mounted the encrypted drives.

trap "exit 255" SIGTERM

sem="$1"
shift 1

[[ ! -f "${sem}" ]] && echo "Waiting for Semaphore '${sem}' before starting '$*'"

n=0
while :; do
	[[ -n $SF_DEBUG ]] && echo "Round #${n}"
	[[ -e "${sem}" ]] && { echo "Found after #${n} rounds..."; exec "$@"; }
	n=$((n+1))
	[[ $n -gt 10 ]] && break
	sleep 1
done

echo "Semaphore '${sem}' does not yet exist. Exiting."
exit 123
