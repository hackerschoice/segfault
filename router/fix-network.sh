#! /bin/bash

# Executed on HOST network namespace.

# shellcheck disable=SC1091 # Do not follow
source "/sf/bin/funcs.sh" || exit 255
source "/sf/bin/funcs_net.sh" || exit 255

set -o pipefail

# NOTE: The iptable rules set inside this container are not visible (iptables -S) on the host
# even that 'network_mode: host' is set. Yet the rule are working on the host side (Why?).
# Furthermore, creating the correct link on the host in /var/run/netns to make the docker namespace
# show up in 'ip netns list' and entering the namespace 'ip netns exec' still wont show
# the iptable rules set inside this container. (Why?).
# See also
# - https://stackoverflow.com/questions/31265993/docker-networking-namespace-not-visible-in-ip-netns-list
# - https://upload.wikimedia.org/wikipedia/commons/3/37/Netfilter-packet-flow.svg

# Once
ipt()
{
	local first
	first="$1"

	shift 1
	iptables -C "$@" 2>/dev/null && return # Rule already exists

	iptables "$first" "$@"
}

# We need to use our own forwarding rules. Docker-compose otherwise spawns a separate process
# for _every_ port - which exceeds Docker's own startup timer if to many ports are forwarded
# and thus docker-compose will fail to start.
#
# Forward traffic to docker
# [UDP/TCP] [PORT-RANGE] [DSTIP]
fw2docker()
{
	local proto
	local range
	local dstip
	proto="$1"
	range="$2"
	dstip="$3"

	# Debugging:
	#  iptables -t raw -I PREROUTING -p udp --dport 55372 -j TRACE
	#  xtables-monitor --trace
	ipt -I PREROUTING -t nat -i "${dev:?}" -d "${mainip}" -p "${proto}" --dport "${range}" -j DNAT --to-destination "${dstip}" || return
	# Accept forward in case the host's FORWARD policy is set to DROP
	ipt -I DOCKER-USER -o "${dev_br:?}" -d "${dstip}" -p "${proto}" --dport "${range}" -j ACCEPT || return

	[[ -z $SF_DEBUG ]] && return

	# #1 - Special hack when connecting from localhost to 10.0.2.15
	ipt -I OUTPUT -t nat -o lo -d "${mainip}" -p "${proto}" --dport "${range}" -j DNAT --to-destination "${dstip}" || return
	# #2 - When connecting from localhost to 127.0.0.1 (#1 is also required)
	ipt -I OUTPUT -t nat -o lo -s 127.0.0.1 -d 127.0.0.1  -p "${proto}" --dport "${range}" -j DNAT --to-destination "${dstip}" || return
	ipt -A POSTROUTING -t nat -s 127.0.0.1 -d "${dstip}" -p "${proto}" --dport "${range}" -j SNAT --to "${NET_DIRECT_BRIDGE_IP:?}" || return
}

# This is a hack.
# - Docker sets the default route to IP of the host-side of the bridge
# - Our 'sf-router' container likes to receive all the traffic instead.
# - Remove host's bridge ip address (flush) 
# - sf-router's init.sh script will take over the IP of host's bridge (and thus receiving all traffic)
# An alternative would be to assign a default gw in user's sf-shell
# and use nsenter -n to change the default route (without giving NET_ADMIN
# to the user).
# The bridge may already be addressless from a previous run.
network_info=$(docker network inspect sf-guest) || ERREXIT 255 "Failed to inspect Docker network sf-guest."
dev_lg=$(jq -er --arg subnet "${NET_LG:?}" '
	.[0] | select(.Driver == "bridge" and any(.IPAM.Config[]; .Subnet == $subnet))
	| (.Options["com.docker.network.bridge.name"] // "") as $name
	| if $name != "" then $name else "br-" + .Id[0:12] end
' <<<"$network_info") || ERREXIT 255 "Docker network sf-guest does not match NET_LG=$NET_LG."
ip -j -d link show dev "$dev_lg" | jq -e 'length == 1 and .[0].linkinfo.info_kind == "bridge"' >/dev/null ||
	ERREXIT 255 "Guest bridge $dev_lg is missing or is not a bridge."

mainip=$(GetMainIP)
dev=$(DevByIP "${mainip:?}") || ERREXIT 255 "Failed to find main network device on host."
dev_br=$(DevByIP "${NET_DIRECT_BRIDGE_IP:?}") || ERREXIT 255 "Failed to find direct bridge on host."
[[ $dev_lg != "$dev" && $dev_lg != "$dev_br" ]] ||
	ERREXIT 255 "Guest bridge $dev_lg overlaps a forwarding interface."

# Remove _any_ ip from the interface. This means LGs can never exit
# to the Internet via the host but still route packets to sf-router.
# sf-router is taking over the IP NET_LG_ROUTER_IP.
ip link set "$dev_lg" arp off || ERREXIT 255 "Failed to disable ARP on guest bridge $dev_lg."
ip addr flush "$dev_lg" || ERREXIT 255 "Failed to remove addresses from guest bridge $dev_lg."

## NOTE: Flushing POSTROUTING may screw up dns-doh (when dns-doh tries to reconnect)
# iptables -t nat -F PREROUTING
# iptables -t nat -F OUTPUT
# iptables -t nat -F POSTROUTING
fw2docker "udp" "32768:65535" "${NET_DIRECT_WG_IP:?}" || ERREXIT 255 "Failed to configure WireGuard forwarding."
# MOSH forwards to sf-router (for traffic control)
fw2docker "udp" "25002:26023" "${NET_DIRECT_ROUTER_IP:?}" || ERREXIT 255 "Failed to configure MOSH forwarding."

# [[ -n $SF_DEBUG ]] && sysctl -w "net.ipv4.conf.${dev_br}.route_localnet=1"

exit 0
