#! /bin/bash

# This is a hack.
# - Docker sets the default route to 10.11.0.1 which is the host-side of the bridge.
# - Our 'router' instance likes to receive all the traffic instead.
# - Remove host's bridge ip of 10.11.0.1 (set to 10.255.255.254/31 or any nonsense)
# - Router's init.sh script will take over 10.11.0.1
# An alternative would be to assign a default gw in user's sf-shell but this
# would require NET_ADMIN, which we dont want to grant the user.
#
ERREXIT()
{
	local code
	code="$1"
	shift 1

	[[ -z $code ]] && exit 0
	echo -e >&2 "$@"
	exit "$code"
}

[[ -n $SF_DEBUG ]] && {
	ip link show >&2
	ip addr show >&2
	ip route show >&2
}

ip addr show | grep 'inet 10\.255\.255\.254' >/dev/null && ERREXIT 0 "Host's bridge already fixed and set to 10.255.255.254."

l=$(ip addr show | grep 'inet 10\.11\.' | head)
[[ -z $l ]] && ERREXIT 255 "Failed to find network"

DEV="$(echo "$l" | awk '{ print $7; }')"
[[ -z $DEV ]] && ERREXIT 254 "Failed to find device"

ip link show "$DEV" >/dev/null || ERREXIT 253 "Failed to find device (DEV='${DEV}')"
# Set to anything non-existing like 10.255...
/usr/sbin/ifconfig "$DEV" 10.255.255.254/31 && ERREXIT 0 "SUCCESS"

ERREXIT 252 "Failed to disable host's bridge"

