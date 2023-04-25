
DevByIP()
{
	local dev

	[[ -z $1 ]] && { echo >&2 "Paremter missing"; return 255; }
	dev=$(ip addr show | grep -F "inet $1")
	dev="${dev##* }"
	[[ -z $dev ]] && { echo -e >&2 "DEV not found for ip '$1'"; return 255; }
	echo "$dev"
}


GetMainIP()
{
	local arr
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
	local key
	dev=$1
	rate=$2
	key=$3

	# Should not happen:
	tc qdisc del dev "${dev}" root 2>/dev/null

	set -e
	sfq_parent=("root")
	[[ -n $rate ]] && {
		tc qdisc  add dev "${dev}" root handle 1: htb
		tc class  add dev "${dev}" parent 1: classid 1:10 htb rate "${rate}"
		tc filter add dev "${dev}" parent 1: protocol ip matchall flowid 1:10
		sfq_parent=("parent" "1:10")
	}

	tc qdisc  add dev "${dev}" "${sfq_parent[@]}" handle 11: sfq
	tc filter add dev "${dev}" parent 11: handle 11 flow hash keys "${key}" divisor 1024
	set +e
}
