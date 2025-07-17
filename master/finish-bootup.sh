#! /bin/bash

# Context: sf-finish-bootup
# Last script to run after bootup.
# - Add default routes to varous containers.

# shellcheck disable=SC1091 # Do not follow
source "/sf/bin/funcs.sh"
source "/sf/bin/funcs_net.sh"

set -e  # Exit immediately on error
# Odd, we need a delay here because (for a reason I don't understand) sometimes
# this runs so early before the network is set up in sf-dnscrypt.
# (Docker documentation says this is impossible, but it happens))
sleep 2
PID="$(docker inspect -f '{{.State.Pid}}' sf-dnscrypt)"
nsenter -t "${PID}" -n ip route add "${SF_NET_LG:?}" via "${SF_NET_VPN_ROUTER_IP}"

# Keep this running so we can inspect iptables rules (for debugging only)
[ -n "$SF_DEBUG" ] && exec -a '[network-fix] sleep' sleep infinity
exit 0
