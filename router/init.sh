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
# TOR traffic (10.11.0.0/16) goes to TOR (transparent proxy)
ip route add 10.111.0.0/16 via 10.11.255.251 && \
# MASQ so that TOR's return traffic goes through this router (for Traffic Control; tc)
iptables -t nat -A POSTROUTING -o eth1 -d 10.111.0.0/16 -j MASQUERADE
echo -e >&2 "FW: SUCCESS" && \

/tc.sh "${DEV_GW}" "${DEV}" && \
echo -e >&2 "TC: SUCCESS" && \

# Sleep forever. This allows admin to attach to router
# and muddle with Traffic Control
exec -a "[sf-router] sleep" sleep infinity

ip route del default
echo -e >&2 "FAILED to set routes"
exit 250

