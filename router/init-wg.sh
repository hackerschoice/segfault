#! /bin/bash

# NOTE: The WG/UDP forwarding rules are set in fix-network.sh
source "/sf/bin/funcs.sh"
source "/sf/bin/funcs_net.sh"

unset SF_MAXOUT
unset SF_MAXIN
eval "$(grep ^SF_MAX /config/host/etc/sf/sf.conf)"

# The WG router goes directly to the Internet (and not via sf-router). Thus
# we must traffic shape here (rather then sf-router).
[[ -n $SF_MAXOUT ]] && {
    tc_set eth0 "${SF_MAXOUT}" "dsthost" "dst" || SLEEPEXIT 255 5 "tc failed"
}

# Could 'police' incoming traffic but it's ugly and incoming traffic is normally
# free anyhow.
[[ -n $SF_MAXIN ]] && SLEEPEXIT 0 5 "WARNING: Incoming WireGuard traffic can not be limited"

# Keep 1 process alive so that master can use `nsenter` to enter this network namespace
exec -a '[wg-sleep]' sleep infinity