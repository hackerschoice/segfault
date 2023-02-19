#! /bin/bash

# https://openwrt.org/docs/guide-user/network/traffic-shaping/packet.scheduler.example4
# https://wiki.archlinux.org/title/advanced_traffic_control
# https://mirrors.bieringer.de/Linux+IPv6-HOWTO/x2759.html
# Note: hsfc and fq_codel stop working after 30 seconds or so (100% packet loss). (odd?)

# Testing:
# docker run --rm -p7575 -p7576 -p7677  -it sf-guest bash -il
# -> 3 tmux panes with each iperf3 -s -p 757[567]
# docker run --rm -it --privileged sf-guest bash -il
# ifconfig eth0:0 172.17.0.5
# iperf3 -c 172.17.0.2 -p 7575 -l1024 -t60-  & iperf3 -c 172.17.0.2 -p 7576 -l1024 -t60- & iperf3 -B 172.17.0.5 -c 172.17.0.2 -l1024 -p7577 -t60
#
# tc -s -d qdisc show

source "/sf/bin/funcs.sh"
source "/sf/bin/funcs_net.sh"

unset SF_MAXOUT
unset SF_MAXIN
eval "$(grep ^SF_MAX /config/host/etc/sf/sf.conf)"

[[ -z $SF_MAXOUT ]] && [[ -z $SF_MAXIN ]] && { echo -e >&2 "WARNING: NO TRAFFIC LIMIT configured."; exit 0; }

# User's INCOMING traffic to his shell. Normally not limited.
DEV_SHELL=${1:-eth1}

# All outgoing interfaces
DEV_GW=${2:-eth3}     # Traffic via VPN (from User's shell)
DEV_DIRECT=${3:-eth0} # SSHD return traffic to User

tc qdisc del dev "${DEV_GW}" root 2>/dev/null
tc qdisc del dev "${DEV_DIRECT}" root 2>/dev/null
tc qdisc del dev "${DEV_SHELL}" root 2>/dev/null

unset err
[[ -n $SF_MAXOUT ]] && {
	### Shape/Limit VPN gateway first (LG -> VPN)
	tc_set "${DEV_GW}" "${SF_MAXOUT}" "nfct-src" || err=1

	### Shape DIRECT network next (LG's SSHD -> DirectInternet)
	tc_set "${DEV_DIRECT}" "${SF_MAXOUT}" "dst" || err=1
}

[[ -n $SF_MAXIN ]] &&  {
	tc_set "${DEV_SHELL}" "${SF_MAXIN}" "src"  || err=1
}

[[ -n $err ]] && SLEEPEXIT 0 5 "cls_matchall.ko not available? NO TRAFFIC LIMIT."

exit 0