#! /bin/bash

# This script is executed from 'sf-fw.service' and from 'sf-monitor.sh'

BASEDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
source "${BASEDIR}/funcs" || exit 255

[[ -z $DEV ]] && for DEV in eth0 ens5 enp0s3; do
  ip link show "$DEV" &>/dev/null && break
done

[[ -z $GW ]] && GW="$(netstat -rn | grep ^0\.0\.0\.0 | tail -n1| awk '{ print $2; }')"
# [[ -z $IP ]] && IP="$(ip addr show dev $DEV | grep 'inet ' | sed 's/.*inet \(.*\)\/.*/\1/g')"

[[ -z $GW ]] && ERREXIT 255 "GW= not set to default gw"
# [[ -z $IP ]] && ERREXIT 255 "IP= not set to my main IP"
ip link show "$DEV" &>/dev/null || ERREXIT 255 "DEV= not set or network device not found." 

# NordVPN is configured with autoconnect=on but systemd has no means
# of knowing when NordVPN has connected fully. Thus we trigger
# 'nordvpn connect' - which will block & wait until fulluy connected.
#nordvpn connect United_Kingdom
#nordvpn connect Onion_Over_VPN
[[ "$(nordvpn status)" = *"Status: Connected"* ]] || {
  nordvpn connect || { echo "NordVPN Connection Failed"; exit 248; }
}

### NordVPN forces _all_ traffic through tun0. We only want docker traffic
### (e.g. forwarded traffic) to go through NordVPN
#############################################################################

# Mark locally generated traffic (OUTPUT)
iptables -t mangle -A OUTPUT -o tun0 -j MARK --set-mark 3

# Force marked traffic to default GW
ip route add default via "${GW}" dev "${DEV}" table 3
ip rule add fwmark 3 table 3

# All packets forced to default GW need to MASQ their source IP
iptables -t nat -A POSTROUTING -o "${DEV}" -m mark --mark 3 -j MASQUERADE

### Allow some docker traffic to _not go_ via NordVPN (e.g incoming ssh)
########################################################################

# NOTE: Docker on Linux does not use docker-proxy but instead uses netfilter
# rules to forward traffic from port 22 to port 2222. Need to hack the rules
# to stop all but legitimate traffic when NordVPN is down.

# Mark allowed traffic leaving from instances to real Internet. In this case
# only allow port 2222 (which docker's netfilter rules turn into 22)
iptables -t mangle -A PREROUTING -p tcp --sport 2222 -m conntrack --ctstate ESTABLISHED,RELATED -j MARK --set-mark 9
ip rule add fwmark 9 table 3

### Prevent traffic from leaving docker-instances when NordVPN is
### disconnected.
#################################################################

# Stop all docker traffic unless it's marked (e.g. all but SSH)
# Drop all that are not marked but attempt to leave via real Internet.
iptables -I FORWARD 1 -o "${DEV}" -m mark ! --mark 9 -j DROP


