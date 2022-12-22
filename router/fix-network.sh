#! /bin/bash

# This is a hack.
# - Docker sets the default route to 169.254.224.1 which is the host-side of the bridge.
# - Our 'router' instance likes to receive all the traffic instead.
# - Remove host's bridge ip of 169.254.224.1 
# - Router's init.sh script will take over 169.254.224.1
# An alternative would be to assign a default gw in user's sf-shell
# and use nsenter -n to change the default route (without giving NET_ADMIN
# to the user).

ERREXIT()
{
	local code
	code="$1"
	shift 1

	[[ -z $code ]] && exit 0
	echo -e >&2 "$@"
	exit "$code"
}

l=$(ip addr show | grep -F "inet ${NET_LG_ROUTER_IP}" | head -n1)
[[ -z $l ]] && ERREXIT 255 "Failed to find network"

DEV="$(echo "$l" | awk '{ print $7; }')"
[[ -z $DEV ]] && ERREXIT 254 "Failed to find device (l=$l)"

# Remove _any_ ip from the interface. This means LGs can never exit
# to the Internet via the host but still route packets to sf-router.
# sf-router is taking over the IP NET_LG_ROUTER_IP
ip link set "$DEV" arp off
ip addr flush "$DEV"


STOP HERE: ADD firewall/forwards for WG setup here. Call this bootup.sh