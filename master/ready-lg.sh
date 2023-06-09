#! /bin/bash

# [LID] [C_IP] [LG_PID]
#
# Called by segfaultsh to 'ready' the LG
# - Set up static ARP entries on RPC, ROUTER and LG
# - Set up Firwall rules inside LG

source /sf/bin/funcs.sh || exit 255
source /dev/shm/config-lg.txt || exit 255

[[ ${#} -lt 3 ]] && exit 255

LID="$1"
C_IP="$2"
LG_PID="$3"
LID_PROMPT_FN="/dev/shm/sf/self-for-guest/lg-${LID}/prompt"

# Create 'empty' for ZSH's prompt to show WG EXIT
[[ ! -f "${LID_PROMPT_FN}" ]] && touch "${LID_PROMPT_FN}"

set -e
LG_MAC=$(docker inspect -f '{{ (index .NetworkSettings.Networks "sf-guest").MacAddress }}' "lg-${LID:?}")

# nsenter -t "${SF_ROUTER_PID:?}" -n ip neigh add "${C_IP:?}" lladdr "${LG_MAC:?}" dev XXX 
nsenter -t "${SF_ROUTER_PID:?}" -n arp -s "${C_IP:?}" "${LG_MAC:?}"

nsenter.u1000 -t "${LG_PID:?}" --setuid 0 --setgid 0 -n arp -s "${SF_NET_LG_ROUTER_IP}" "${LG_ROUTER_MAC}"
nsenter.u1000 -t "${LG_PID:?}" --setuid 0 --setgid 0 -n arp -s "${SF_RPC_IP}"           "${LG_RPC_MAC}"

# 255.0.0.1 always points to guest's localhost: user can now set up a ssh -D1080 and connect with browser to
# 255.0.0.1 and reach guest's 127.0.0.1.
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p tcp --dst 255.0.0.1 -j DNAT --to-destination 127.0.0.1
set +e

exit 0