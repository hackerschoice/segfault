#! /bin/bash

tc_set()
{
	local dev
	local rate
	dev="$1"
	rate="$2"

	# Installs a class based queue
	tc qdisc add dev "${dev}" root handle 1: cbq avpkt 1000 bandwidth 1000mbit 

	# Create a shaped class
	tc class add dev "${dev}" parent 1: classid 1:1 cbq rate "${rate:-1000Mbit}" \
		  allot 1500 prio 5 bounded isolated

	# Send all traffic through the shaped class
	tc filter add dev "${dev}" parent 1: matchall flowid 1:1
}

[[ ! -f /config/tc/limits.conf ]] && { echo -e >&2 "WARNING: NO OUTGOING TRAFFIC LIMIT"; exit 0; }

DEV_OUT=${1:-eth0}
DEV_IN=${2:-eth1}
# shellcheck disable=SC1091
source /config/tc/limits.conf

# Limits in limits.conf overwrite limits set by environment variable
# SF_MAXOUT= / SF_MAXIN=
[[ -z $MAXOUT ]] && MAXOUT="${SF_MAXOUT}"
[[ -z $MAXIN ]] && MAXIN="${SF_MAXIN}"

# Delete all. This might set $? to false
tc qdisc del dev "${DEV_OUT}" root 2>/dev/null
# force $? to be true

[[ -n $MAXOUT ]] && { tc_set "${DEV_OUT}" "${MAXOUT}" || exit 255; }
[[ -n $MAXIN ]] && { tc_set "${DEV_IN}" "${MAXIN}" || exit 255; }

exit 0
