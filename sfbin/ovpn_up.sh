#! /bin/bash
# Executed by OpenVPN --up within master/OpenVPN context

source /sf/bin/funcs_net.sh

# echo "$*" >/tmp/up_args.txt
# set >/tmp/up_set.txt

[[ -z $WG_DEV ]] && WG_DEV="vpnEXIT"

# Inside this context the PATH needs to be exported:
export PATH

# Add the OpenVPN PEER as default route
nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID:?}" -n ip route add "${trusted_ip:?}" via "${SF_NET_LG_ROUTER_IP:?}" dev eth0
# Remove old default route.

cd "/tmp/lg-${LID:?}/conf"
[[ -f "route" ]] && IFS=$'\n' readarray -t R_ROUTE_ARR <"route"

set_route_post_up
# Remove all BLOCKING OUTPUT rules that were needed between OpenVPN starting
# and the device becoming available.
nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n iptables -F OUTPUT
rm -rf "/tmp/lg-${LID}/conf"

