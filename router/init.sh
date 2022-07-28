#! /bin/bash

# - Take over 10.11.0.1.
# - Force default route to NordLynx 

TOR_GW="172.20.0.111"
VPN_GW="172.20.0.254"
GOOD_ROUTES+=("10.11.0.0/16")
GOOD_ROUTES+=("10.111.0.0/16") # TOR
GOOD_ROUTES+=("172.20.0.0/24")
GOOD_ROUTES+=("172.20.1.0/24")
GOOD_ROUTES+=("172.23.0.0/24")

# https://en.wikipedia.org/wiki/Reserved_IP_addresses
BAD_ROUTES+=("0.0.0.0/8")
BAD_ROUTES+=("10.0.0.0/8")
BAD_ROUTES+=("172.16.0.0/12")
BAD_ROUTES+=("100.64.0.0/10")
BAD_ROUTES+=("169.254.0.0/16")
BAD_ROUTES+=("192.0.0.0/24")
BAD_ROUTES+=("192.0.2.0/24")
BAD_ROUTES+=("192.88.99.0/24")
BAD_ROUTES+=("192.168.0.0/16")
BAD_ROUTES+=("198.18.0.0/15")
BAD_ROUTES+=("198.51.100.0/15")
BAD_ROUTES+=("203.0.113.0/24")
BAD_ROUTES+=("224.0.0.0/4")
BAD_ROUTES+=("233.252.0.0/24")
BAD_ROUTES+=("240.0.0.0/24")
BAD_ROUTES+=("255.255.255.255/32")

blacklist_routes()
{
	for ip in "${GOOD_ROUTES[@]}"; do
		iptables -A FORWARD -d "$ip" -j ACCEPT
	done

	for ip in "${BAD_ROUTES[@]}"; do
		iptables -A FORWARD -d "$ip" -j REJECT
	done
}

devbyip()
{
	# shellcheck disable=SC2005
	echo "$(ip addr show | grep -F "inet $1" | head)" | awk '{ print $7; }'
}

# Stop routing via VPN
vpn_unset()
{
	ip route del default via "${VPN_GW}"
}

# Start routing via VPN
vpn_set()
{
	ip route add default via "${VPN_GW}"
}

tor_unset()
{
	unset IS_SET_TOR
	ip route del default via "${TOR_GW}"
}

tor_set()
{
	IS_SET_TOR=1
	ip route add default via "${TOR_GW}"
}

monitor_failover()
{
	# ts=$(date +%s)

	while :; do
		if [[ -n $IS_SET_TOR ]]; then
			# HERE: TOR is set
			if [[ -f /sf/run/vpn/vpn_status ]]; then
				# HERE: VPN is back
				echo -e >&2 "$(date) WARN: Switching route to VPN."
				tor_unset
				vpn_set
			fi
		else
			# HERE: TOR is NOT set
			# Run a ping test. On failure 
			if [[ ! -f /sf/run/vpn/vpn_status ]]; then
				# HERE: VPN is gone
				echo -e >&2 "$(date) WARN: Switching route to TOR."
				vpn_unset
				tor_set
			fi
		fi
		sleep 5
	done
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

blacklist_routes

ip route del default && \
ifconfig "$DEV" 10.11.0.1/16 && \
# MASQ all traffic because the VPN/TOR systems dont know the route back
# to sf-guest (10.11.0.0/16).
iptables -t nat -A POSTROUTING -o "${DEV_GW}" -j MASQUERADE && \
# TOR traffic (10.111.0.0/16) always goes to TOR (transparent proxy)
ip route add 10.111.0.0/16 via "${TOR_GW}" && \
echo -e >&2 "FW: SUCCESS" && \

/tc.sh "${DEV_GW}" "${DEV}" && \
echo -e >&2 "TC: SUCCESS" && \

# By default go via TOR until vpn_status exists
tor_set
monitor_failover
# Sleep forever. This allows admin to attach to router
# and muddle with Traffic Control
# exec -a "[sf-router] sleep" sleep infinity

ip route del default
echo -e >&2 "FAILED to set routes"
exit 250

