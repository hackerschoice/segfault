
DevByIP()
{
	local dev

	[[ -z $1 ]] && { echo >&2 "Parameter missing"; return 255; }
	dev=$(ip addr show | grep -F "inet $1")
	dev="${dev##* }"
	[[ -z $dev ]] && { echo -e >&2 "DEV not found for ip '$1'"; return 255; }
	echo "$dev"
}


GetMainIP()
{
	local arr
	local -
	set -o noglob
	arr=($(ip route get 8.8.8.8))
	echo "${arr[6]}"
}

# https://openwrt.org/docs/guide-user/network/traffic-shaping/packet.scheduler.example4
# https://wiki.archlinux.org/title/advanced_traffic_control
# https://mirrors.bieringer.de/Linux+IPv6-HOWTO/x2759.html
# https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.qdisc.classful.html
# Note: hsfc and fq_codel stop working after 30 seconds or so (100% packet loss). (odd?)

# When traffic enters a classful qdisc, it needs to be sent to any of the classes
# within - it needs to be 'classified'. To determine what to do with a packet, the
# so called 'filters' are consulted. It is important to know that the filters are
# called from within a qdisc, and not the other way around!
#
# Assign a SFQ to give all LG's a fair share.
# Testing:
# docker run --rm -p7575 -p7576 -p7677  -it sf-guest bash -il
# -> 3 tmux panes with each iperf3 -s -p 757[567]
# docker run --rm -it --privileged sf-guest bash -il
# ifconfig eth0:0 172.17.0.5
# iperf3 -c 172.17.0.2 -p 7575 -l1024 -t60-  & iperf3 -c 172.17.0.2 -p 7576 -l1024 -t60- & iperf3 -B 172.17.0.5 -c 172.17.0.2 -l1024 -p7577 -t60
#
# tc -s -d qdisc show
tc_set()
{
	local dev
	local rate
	local cakekey
	local key
	dev=$1
	rate=$2
	cakekey=$3
	key=$4

	# Should not be set but lets make sure:
	tc qdisc del dev "${dev}" root 2>/dev/null

	# use TC-CAKE if there is a rate limit. Otherwise use faster SFQ below.
	[[ -n $rate ]] && {
		tc qdisc add dev "${dev}" root cake bandwidth "${rate}" "${cakekey}"
		return
	}

	set -e
	tc qdisc  add dev "${dev}" root handle 11: sfq
	tc filter add dev "${dev}" parent 11: handle 11 flow hash keys "${key}" divisor 1024
	set +e
}

set_route_pre_up() {
	# Add static routes for Segfault Services (RPC, DNS, ...)
	# nsenter -t "${LG_PID}" -n ip route add "${SF_PC_IP}/32" dev eth0 # NOT NEEDED: RPC is on same network
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add "${SF_TOR_IP}" via "${SF_NET_LG_ROUTER_IP}" dev eth0 2>/dev/null
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add "${SF_DNS}" via "${SF_NET_LG_ROUTER_IP}" dev eth0 2>/dev/null
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add "${SF_NET_ONION}" via "${SF_NET_LG_ROUTER_IP}" dev eth0 2>/dev/null
	[[ -n $SF_MULLVAD_ROUTE ]] && nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add "${SF_MULLVAD_ROUTE}" via "${SF_NET_LG_ROUTER_IP}" dev eth0 2>/dev/null
}

set_route_post_up() {
	local str

	# If there is a EXTRA ROUTE then route ALL traffic. Otherwise keep default route
	# but add EXTRA ROUTE.
	[[ ${#R_ROUTE_ARR[@]} -eq 0 ]] && {
		nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route del default 2>/dev/null
        nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add default dev "${WG_DEV}"
	}
	# All IPv6 to WG_DEV. FIXME: One day we shall support IPv6
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip -6 route del default 2>/dev/null
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip -6 route add default dev "${WG_DEV}" 2>/dev/null

	# Add EXTRA ROUTE
    for str in "${R_ROUTE_ARR[@]}"; do
		echo "Setting route $str"
        nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip route add "${str}" dev "${WG_DEV}"
    done

	# Packets to 172.16.0.3 should not be forwarded back to 172.16.0.3
	# Can not use 'sysctl net.ipv4.conf.wgExit.forwarding=1' because /proc is mounted ro
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n iptables  -C FORWARD -i "${WG_DEV}" -j DROP &>/dev/null || \
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n iptables  -I FORWARD -i "${WG_DEV}" -j DROP
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip6tables -C FORWARD -i "${WG_DEV}" -j DROP &>/dev/null || \
	nsenter.u1000 --setuid 0 --setgid 0 -t "${LG_PID}" -n ip6tables -I FORWARD -i "${WG_DEV}" -j DROP
}

# sf-master, wg/vpn
set_route()
{
	# Can be removed for future release:
	PID="${LG_PID:-$PID}" # Hot-Fix when on lsd we had some routines call this with PID and others with LG_PID

	set_route_pre_up
	set_route_post_up
}
