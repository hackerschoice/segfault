#! /bin/bash

# - Take over 10.11.0.1.
# - Force default route to NordLynx 

devbyip()
{
	echo $(ip addr show | grep -F "inet $1" | head) | awk '{ print $7; }'
}

DEV="$(devbyip 10.11.)"
[[ -z $DEV ]] && { echo -e >&2 "DEV not found. Using DEV=eth1"; DEV="eth1"; }

DEV_GW="$(devbyip 172.20.0.)"
[[ -z $DEV_GW ]] && { echo -e >&2 "DEV not found. Using DEV_GW=eth0"; DEV_GW="eth0"; }

[[ -n $SF_DEBUG ]] && {
	ip link show >&2
	ip addr show >&2
	ip route show >&2

	echo >&2 "DEV=${DEV} DEV_GW=${DEV_GW}"
}

ip route del default && \
ip route add default via 172.20.0.254 && \
ifconfig "$DEV" 10.11.0.1/16 && \
iptables -t nat -A POSTROUTING -o "${DEV_GW}" -j MASQUERADE && \
echo -e >&2 "SUCCESS" && \
# Sleep forever. This allows admin to attach to router
# and muddle with Traffic Control
exec -a "[sf-router] sleep" sleep infinity



echo -e >&2 "FAILED to set routes"
exit 250

