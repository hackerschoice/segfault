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
	tc filter add dev "${dev}" parent 1: matchall flowid 1:1 || { echo -e >&2 "cls_matchall.ko not available? NO TRAFFIC LIMIT."; sleep 5; return 0; }
}

unset SF_MAXOUT
unset SF_MAXIN
eval "$(grep ^SF_MAX /config/host/etc/sf/sf.conf)"

[[ -z $SF_MAXOUT ]] && [[ -z $SF_MAXIN ]] && { echo -e >&2 "WARNING: NO TRAFFIC LIMIT configured."; exit 0; }

# User's INCOMING traffic to his shell. Normally not limited.
DEV_SHELL=${1:-eth1}

# All outgoing interfaces
DEV_GW=${2:-eth3}  # Traffic via VPN (User's shell)
DEV_DIRECT=${3:-eth0} # SSHD return traffic to User

# Delete all. This might set $? to false
tc qdisc del dev "${DEV_GW}" root 2>/dev/null
tc qdisc del dev "${DEV_DIRECT}" root 2>/dev/null
true # force $? to be true

[[ -n $SF_MAXOUT ]] && { tc_set "${DEV_GW}" "${SF_MAXOUT}" || exit 255; }
[[ -n $SF_MAXOUT ]] && { tc_set "${DEV_DIRECT}" "${SF_MAXOUT}" || exit 255; }

[[ -n $SF_MAXIN ]] && { tc_set "${DEV_SHELL}" "${SF_MAXIN}" || exit 255; }

exit 0
