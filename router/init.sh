#! /bin/bash

# - Take over 10.11.0.1.
# - Force default route to NordLynx 

TOR_GW="172.20.0.111"
GOOD_ROUTES+=("10.11.0.0/16")
GOOD_ROUTES+=("10.111.0.0/16") # TOR
GOOD_ROUTES+=("172.20.0.0/24") # VPN gateways
GOOD_ROUTES+=("172.20.1.0/24")
GOOD_ROUTES+=("172.22.0.0/24")
GOOD_ROUTES+=("172.23.0.0/24")
GOOD_ROUTES+=("172.28.0.0/24")

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
		iptables -A FORWARD -p tcp -d "$ip" -j REJECT --reject-with tcp-reset
		iptables -A FORWARD -d "$ip" -j REJECT
	done
}

devbyip()
{
	local dev
	dev="$(ip addr show | grep -F "inet $1" | head -n1 | awk '{print $7;}')"
	[[ -n $dev ]] && { echo "$dev"; return; }
	echo -e >&2 "DEV for '${1}' not found. Using $2"
	echo "${2:?}"
}

init_revport()
{
	[[ -n $IS_REVPORT_INIT ]] && return
	IS_REVPORT_INIT=1
	### Create routing tables for reverse connection and when multipath routing is used:
	# We are using multipath routing _and_ reverse port forwarding from the VPN Provider.
	# See Cryptostorm's http://10.31.33.7/fwd as an example:
	# The reverse connection has the true source IP but our router's multipath route
	# might return the SYN/ACK via a different path. Thus we mark all new incoming
	# connections (from the VPN provider) and route the reply out the same GW it came in
	# from. The (cheap) alternative would be to use SNAT and MASQ but then the guest's
	# root server would not see the true source IP of the reverse connection.

	# Get the MAC address of all routers.
	unset ips
	for n in {240..254}; do ips+=("172.20.0.${n}"); done
	fping -c3 -A -t20 -p10 -4 -q "${ips[@]}" 2>/dev/null 

	# Mark every _NEW_ connection from VPN 
	unset ips
	iptables -A PREROUTING -t mangle -i "${DEV_GW}" -j CONNMARK --restore-mark
	iptables -A PREROUTING -t mangle -i "${DEV_GW}" -m mark ! --mark 0 -j ACCEPT
	iptables -A PREROUTING -t mangle -i "${DEV_GW}" -m mark --mark "11${n}" -j ACCEPT
	for n in {240..254}; do
		mac="$(ip neigh show 172.20.0."${n}")"
		mac="${mac##*lladdr }"
		mac="${mac%% *}"
		[[ "${#mac}" -ne 17 ]] && continue # empty or '172.20.0.240 dev eth4 FAILED'

		ips+=("${n}")
		# Mark any _NEW_ connection by GW's mac.
		iptables -A PREROUTING -t mangle -i "${DEV_GW}" -p tcp -m conntrack --ctstate NEW -m mac --mac-source "${mac}" -j MARK --set-mark "11${n}"
		iptables -A PREROUTING -t mangle -i "${DEV_GW}" -p udp -m conntrack --ctstate NEW -m mac --mac-source "${mac}" -j MARK --set-mark "11${n}"
	done
	iptables -A PREROUTING -t mangle -i "${DEV_GW}" -j CONNMARK --save-mark

	echo -e >&2 "[$(date '+%F %T' -u)] RevPort set up for 172.20.0.[${ips[@]}]"

	# Route return traffic back to VPN-GW the packet came in from.
	# Every return packet is marked (11nnn). If it is marked (e.g. it is a return packet)
	# then also mark it as 12nnn. Then use customer routing rule for all packets
	# marked 12nnn.
	# Note: We can not route on 11nnn because this would as well incoming packets (and
	# we only need to route return packets). 

	# Load the ConnTrack MARKS:
	iptables -A PREROUTING -t mangle -i "${DEV}" -j CONNMARK --restore-mark
	for n in "${ips[@]}"; do
		# On return path (-i DEV), add 12nnn mark for every packet that was initially tracked (11nnn).
		iptables -A PREROUTING -t mangle -i "${DEV}" -m mark --mark "11${n}" -j MARK --set-mark "12${n}"
		# Add a routing table for return packets to force them via GW (mac) they came in from.
		ip rule add fwmark "12${n}" table "8${n}"
		ip route add default via "172.20.0.${n}" dev ${DEV_GW} table "8${n}"
	done
}

use_vpn()
{
	local gw
	local gw_ip

	unset IS_TOR

	# Configure FW rules for reverse port forwards.
	# Any earlier than this and the MAC of the routers are not known. Thus do it here.
	init_revport

	local _ip
	local f
	for f in /sf/run/vpn/status-*; do
		[[ ! -f "$f" ]] && break
		_ip="$(<"$f")"
		_ip="${_ip%%$'\n'*}"
		_ip="${_ip##*=}"
		_ip="${_ip//[^0-9\.]/}" # Sanitize
		[[ -z $_ip ]] && continue
		gw+=("nexthop" "via" "${_ip}" "weight" "100")
		gw_ip+=("${_ip}")
	done

	[[ -z $gw ]] && return

	echo -e >&2 "[$(date '+%F %T' -u)] Switching to VPN (gw=${gw_ip[@]})" 
	ip route del default
	ip route add default "${gw[@]}"
}

use_tor()
{
	IS_TOR=1

	echo -e >&2 "$(date) Switching to TOR" 
	ip route del default 2>/dev/null
	ip route add default via "${TOR_GW}"
}

monitor_failover()
{
	local status_sha

	# FIXME: use redis here instead of polling
	while :; do
		bash -c "exec -a '[sleep router failover]' sleep 1"
		sha="$(sha256sum /config/guest/vpn_status 2>/dev/null)"
		[[ "$status_sha" ==  "$sha" ]] && continue

		# Status has changed
		status_sha="${sha}"

		# If vpn_status no longer exists then switch to TOR
		[[ ! -f /config/guest/vpn_status ]] && { use_tor; continue; }

		use_vpn
	done
}


# Delete old vpn_status
[[ -f /config/guest/vpn_status ]] && rm -f /config/guest/vpn_status

DEV_I22="$(devbyip 172.28.0. eth0)"
DEV="$(devbyip 10.11. eth1)"
DEV_SSHD="$(devbyip 172.22.0. eth2)"
DEV_GW="$(devbyip 172.20.0. eth3)"
DEV_DMZ="$(devbyip 172.20.1. eth4)"

echo -e "\
DEV_I22="${DEV_I22}"\n\
DEV="${DEV}"\n\
DEV_SSHD="${DEV_SSHD}"\n\
DEV_GW="${DEV_GW}"\n\
DEV_DMZ="${DEV_DMZ}"\n\
" >/dev/shm/net-devs.txt


[[ -n $SF_DEBUG ]] && {
	ip link show >&2
	ip addr show >&2
	ip route show >&2

	echo >&2 "DEV=${DEV} DEV_GW=${DEV_GW}"
}

blacklist_routes

# -----BEGIN TCP SYN RATE LIMT-----
iptables --new-chain SYN-LIMIT
iptables -I FORWARD 1 -i "${DEV}" -o "${DEV_GW}" -p tcp --syn -j SYN-LIMIT
# Refill bucket at a speed of 20/sec and take out max of 64k at one time.
# 64k are taken and thereafter limit to 20syn/second (as fast as the bucket refills)
iptables -A SYN-LIMIT -m limit --limit "20/sec" --limit-burst 65536 -j RETURN
iptables -A SYN-LIMIT -j DROP
# -----END TCP SYN RATE LIMIT-----

ip route del default && \
# -----BEGIN SSH traffic is routed via Internet-----
# A bit more tricky to forward incoming SSH traffic to our SSHD
# because we also like to see the source IP (User's Workstation's IP).
#
# Must rp_filter=2 (see docker-compose.yml)
# # iptables -t raw -A PREROUTING -p tcp -d 172.20.0.2 --dport 22 -j TRACE
# # iptables -t raw -L -v -n --line-numbers
# # modprobe nf_log_ipv4 && sysctl net.netfilter.nf_log.2=nf_log_ipv4
# - iptables -L PREROUTING -t mangle -n
# - ip rule show
# - ip route show table 207
# Forward all SSHD traffic to sf-host:22.
iptables -A PREROUTING -i ${DEV_I22} -t mangle -p tcp -d 172.28.0.2 --dport 22 -j MARK --set-mark 722 && \
ip rule add fwmark 722 table 207 && \
ip route add default via 172.22.0.22 dev ${DEV_SSHD} table 207 && \

# Any return traffic from the SSHD shall go out (directly) to the Internet.
iptables -A PREROUTING -i ${DEV_SSHD} -t mangle -p tcp -s 172.22.0.22 --sport 22 -j MARK --set-mark 22 && \
ip rule add fwmark 22 table 201 && \
ip route add default via 172.28.0.1 dev ${DEV_I22} table 201 && \

# Forward packets to SSHD (172.22.0.22)
iptables -t nat -A PREROUTING -p tcp -d 172.28.0.2 --dport 22 -j DNAT --to-destination 172.22.0.22 && \
# Make packets appear as if this router was listening on port 22
iptables -t nat -A POSTROUTING -p tcp -s 172.22.0.22 --sport 22 -j SNAT --to-source 172.28.0.2 && \
# When connecting from Docker's host:
# Note: Traffic from router to shell leaves with src=172.28.0.1 and dst=172.22.0.22
# However, at the SSHD they appear to be comming from src=172.22.0.254 because
# Docker's host side bridge performs NAT. On the SSHD side we can not send
# the traffic back to 172.28.0.1 (via 172.22.0.254; this router) because both share the
# same MAC.
# Instead use a hack to force traffic from 172.28.0.1 to be coming
# from 172.22.0.254 (This router's IP)
iptables -t nat -A POSTROUTING -s 172.28.0.1 -o ${DEV_SSHD} -j MASQUERADE && \
# -----END SSH traffic is routed via Internet-----

# -----BEGIN GSNC traffic is routed via Internet----
# GSNC TCP traffic to 443 and 7350 goes to (direct) Internet
iptables -A PREROUTING -i ${DEV_SSHD} -t mangle -p tcp -s 172.22.0.21 -j MARK --set-mark 22
# -----END GSNC traffic is routed via Internet----

ifconfig "$DEV" 10.11.0.1/16 && \
# MASQ all traffic because the VPN/TOR instances dont know the route back
# to sf-guest (10.11.0.0/16).
iptables -t nat -A POSTROUTING -o "${DEV_GW}" -j MASQUERADE && \
# MASQ SSHD's access to DNS (for ssh -D socks5h resolving)
iptables -t nat -A POSTROUTING -s 172.22.0.22 -o "${DEV}" -j MASQUERADE && \
# MASQ GSNC to (direct) Internet
iptables -t nat -A POSTROUTING -s 172.22.0.21 -o "${DEV_I22}" -j MASQUERADE && \
# MASQ traffic from TOR to DMZ (nginx)
iptables -t nat -A POSTROUTING -o "${DEV_DMZ}" -j MASQUERADE && \
# TOR traffic (10.111.0.0/16) always goes to TOR (transparent proxy)
ip route add 10.111.0.0/16 via "${TOR_GW}" && \
echo -e >&2 "FW: SUCCESS" && \
/tc.sh "${DEV}" "${DEV_GW}" "${DEV_I22}" && \
echo -e >&2 "TC: SUCCESS" && \

# By default go via TOR until vpn_status exists
use_tor && \
monitor_failover

# REACHED IF ANY CMD FAILS
ip route del default
echo -e >&2 "FAILED to set routes"
exit 250

