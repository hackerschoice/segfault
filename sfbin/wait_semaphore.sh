#! /bin/bash

# EXIT unless "$2" exists.
#
# This is used by Nginx to keep restarting until the EncFS
# is fully mounted.

trap "exit 255" SIGTERM

sem="$1"
shift 1
echo "Waiting for Semaphore '${sem}' before starting '$*'"

[[ -e "${sem}" ]] && exec "$@"
sleep 1
echo "Semaphore '${sem}' does not yet exist. Exiting."
exit 123
