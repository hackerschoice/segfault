#! /bin/bash

# [LID] [C_IP] [LG_PID]
#
# Context: SF-MASTER
#
# Called by segfaultsh to 'ready' the LG
# - Set up static ARP entries on RPC, ROUTER and LG
# - Set up Firwall rules inside LG

LID="${1:?}"

source /sf/bin/funcs.sh || exit 255
source /dev/shm/config-lg.txt || exit 255
source "/dev/shm/sf/run/users/lg-${LID}/config.txt"

# docker exec sf-router /user-limit.sh "${LID}" || ERREXIT 251 "Failed to set network user-limit...";
nsenter -t "${SF_ROUTER_PID:?}" -n -m /ready-lg-router.sh "${LID}" || ERREXIT 251 "Failed to set network user-limit...";

LID_PROMPT_FN="/dev/shm/sf/self-for-guest/lg-${LID}/prompt"

# Create 'empty' for ZSH's prompt to show WG EXIT
# [[ ! -f "${LID_PROMPT_FN}" ]] && touch "${LID_PROMPT_FN}"
# Overwrite existing. Will be re-created by sf-setup.sh if WG-NET is up still. 
:>"${LID_PROMPT_FN}"

set -e
nsenter.u1000 -t "${LG_PID:?}" --setuid 0 --setgid 0 -n arp -s "${SF_NET_LG_ROUTER_IP}" "${LG_ROUTER_MAC}"
nsenter.u1000 -t "${LG_PID:?}" --setuid 0 --setgid 0 -n arp -s "${SF_RPC_IP}"           "${LG_RPC_MAC}"

# 255.0.0.1 always points to guest's localhost: user can now set up a ssh -D1080 and connect with browser to
# 255.0.0.1 and reach guest's 127.0.0.1.
# iptables is u+s and does not need --setuid
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p tcp --dst 255.0.0.1 -j DNAT --to-destination 127.0.0.1

# Drop SPOOFED IPs. Must be LG's source IP
nsenter.u1000 -t "${LG_PID}" -n iptables -A OUTPUT -o eth0 ! -s "${C_IP:?}" -j DROP

# Create Transparent Proxy cgroup and ipt rules (for curl sf/proxy$$)
# Never redirect traffic to SF internal systems.

[[ -n "$SF_MULLVAD_ROUTE" ]] && nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p tcp -d "$SF_MULLVAD_ROUTE" -j RETURN
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -m addrtype --dst-type LOCAL -j RETURN
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p tcp -d "${SF_RPC_IP:?}" -j RETURN
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p tcp -d "${SF_TOR_IP:?}" -j RETURN
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A OUTPUT -p udp -d "${SF_DNS:?}" -j RETURN

nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -N "OUT-PROXY-${LID}"
nsenter.u1000 -t "${LG_PID}" -n iptables -t nat -A "OUTPUT" -j "OUT-PROXY-${LID}"

# Debian11 does not support net_cls/cgroup. Ignore
set +e
mkdir "/sf-cgroup/docker-${CID:-NULL}.scope/proxy1040"
# nsenter.u1000 -t "${LG_PID}" -n -C iptables -t nat -A "OUT-PROXY-${LID}" -m cgroup --path /proxy1040 -p tcp -j REDIRECT --to-port 1040
# nsenter.u1000 -t "${LG_PID}" -n -C iptables -t nat -A "OUT-PROXY-${LID}" -m cgroup --path /proxy1040 -p udp -j REDIRECT --to-port 1040
set -e

# Set egress limits per LG
[[ -n $USER_UL_RATE ]] && {
	nsenter.u1000 -t "${LG_PID:?}" --setuid 0 --setgid 0 -n tc qdisc add dev eth0 root cake bandwidth "${USER_UL_RATE}" dsthost
	# FIXME: DNS rate limit is currently done with SF_USER_FW limits and set on the sf-router.
	#nsenter.u1000 -t "${LG_PID:?}" iptables -A OUTPUT -o eth0 -p udp --dport 53 -m limit --limit 1/s --limit-burst 100 -j ACCEPT
	#nsenter.u1000 -t "${LG_PID:?}" iptables -A OUTPUT -o eth0 -p udp --dport 53 DROP
}

set +e

exit 0
