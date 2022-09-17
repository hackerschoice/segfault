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
	# Amazon Linux 2 does not come with cls_matchall module
	tc filter add dev "${dev}" parent 1: matchall flowid 1:1 || { echo -e >&2 "cls_matchall.ko not available? Disable traffic limit."; return 0; }
}

[[ ! -f /config/tc/limits.conf ]] && { echo -e >&2 "WARNING: NO OUTGOING TRAFFIC LIMIT"; exit 0; }

# User's INCOMING traffic to his shell. Normally not limited.
DEV_SHELL=${1:-eth1}

# All outgoing interfaces
DEV_GW=${2:-eth3}  # Traffic via VPN (User's shell)
DEV_I22=${3:-eth0} # SSHD return traffic to User

# shellcheck disable=SC1091
source /config/tc/limits.conf

# Limits in limits.conf overwrite limits set by environment variable
# SF_MAXOUT= / SF_MAXIN=
[[ -z $MAXOUT ]] && MAXOUT="${SF_MAXOUT}"
[[ -z $MAXIN ]] && MAXIN="${SF_MAXIN}"

# Delete all. This might set $? to false
tc qdisc del dev "${DEV_GW}" root 2>/dev/null
tc qdisc del dev "${DEV_I22}" root 2>/dev/null
true # force $? to be true

[[ -n $MAXOUT ]] && { tc_set "${DEV_GW}" "${MAXOUT}" || exit 255; }
[[ -n $MAXOUT ]] && { tc_set "${DEV_I22}" "${MAXOUT}" || exit 255; }

[[ -n $MAXIN ]] && { tc_set "${DEV_SHELL}" "${MAXIN}" || exit 255; }

exit 0
