#! /bin/bash

# Context: SF-MASTER
#
# Called every time encfsd shuts down an LG.

LID="${1:?}"

# segfaultsh may have called ERREXIT before container was created (and before config.txt was created)
[ ! -f "/dev/shm/sf/run/users/lg-${LID}/config.txt" ] && exit 0

source "/sf/bin/funcs.sh" || exit 255
source "/dev/shm/config-lg.txt" || exit 255 # For SF_ROUTER_PID
# Log LG_PID
source "/dev/shm/sf/run/users/lg-${LID}/config.txt"

# Wireguard bug in new Linux kernel:
# 1. Assign port to WG
# 2. Move WG into sf-guest
# 3. Destroy sf-guest
# => Port keeps listening: docker exec sf-wg ss -nlu
# => Work-around: Destroy WG before container is killed
lgns() { nsenter.u1000 --setuid 0 --setgid 0 "$@"; }
lgns -t "$LG_PID" -n ip link delete group 31337

# OpenVPN cleanup
killall "openvpn-${LID}" 2>/dev/null
rm -rf "/tmp/lg-${LID}" 2>/dev/null

nsenter -t "${SF_ROUTER_PID:?}" -n -m sh -c '
. "/dev/shm/net-devs.txt"
. "/sf/run/users/lg-'"${LID}"'/config.txt"
LID="'"${LID}"'"
CHAIN="SYN-${SYN_LIMIT}-${SYN_BURST}-${IDX}"
iptables -D FORWARD -i "${DEV_LG:?}" -s "${C_IP:?}" -j "FW-${LID}"
iptables -F "FW-${LID}"
iptables -X "FW-${LID}" || { iptables -F "FW-${LID}"; sleep 1; iptables -X "FW-${LID}"; }
iptables -nL "$CHAIN" | grep -qm1 "^Chain.*0 references" && {
    iptables -F "$CHAIN"
    iptables -X "$CHAIN"
}
'
