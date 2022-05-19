#! /bin/bash

# This script is executed from 'sf-fw.service' and from 'sf-monitor.sh'

BASEDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
source "${BASEDIR}/funcs" || exit 255

# Default it to 'up' the firewall
# sf-fw.services calls 'up_persistent'
[[ "$1" = "down" ]] && { IS_DOWN=1; SF_IS_SKIP_NORDVPN=1; }
[[ "$1" = "up_persistent" ]] && IS_PERSISTENT=1

init_vars()
{
  command -v iptables >/dev/null || ERREXIT 248 "iptables not found..."

  # Find out the main Internet ethernet device
  [[ -z $DEV ]] && for DEV in eth0 ens5 enp0s3; do
    ip link show "$DEV" &>/dev/null && break
  done
  ip link show "$DEV" &>/dev/null || ERREXIT 255 "DEV= not set or network device not found." 

  [[ -z $GW ]] && GW="$(netstat -rn | grep ^0\.0\.0\.0 | tail -n1| awk '{ print $2; }')"
  [[ -z $GW ]] && ERREXIT 255 "GW= not set to default gw"

  # [[ -z $IP ]] && IP="$(ip addr show dev $DEV | grep 'inet ' | sed 's/.*inet \(.*\)\/.*/\1/g')"
  # [[ -z $IP ]] && ERREXIT 255 "IP= not set to my main IP"
}


# Set netfilter rule if not already set
ipt()
{
  if [[ -n $IS_DOWN ]]; then
    while iptables -D $@ 2>/dev/null; do
      :
    done
    return
  fi
  iptables -C $@ 2>/dev/null && return
  iptables -A $@
}

ipt_forward()
{
  if [[ -n $IS_DOWN ]]; then
    while iptables -D FORWARD $@ 2>/dev/null; do
      :
    done
    return
  fi

  iptables -C FORWARD $@ 2>/dev/null && return
  iptables -I FORWARD 1 $@
}

ip_rule_add()
{
  if [[ -n $IS_DOWN ]]; then
    while ip rule del $@ 2>/dev/null; do
      :
    done
    return
  fi
  ip rule add $@
}
ip_route_add()
{
  if [[ -n $IS_DOWN ]]; then
    ip route del $@ 2>/dev/null
    return
  fi
  [[ "$(ip route list $@ | wc -l)" -ne 0 ]] && return
  ip route add $@
}

set_all_rules()
{
  ### NordVPN forces _all_ traffic through tun0. We only want docker traffic
  ### (e.g. forwarded traffic) to go through NordVPN
  #############################################################################

  # Mark locally generated traffic (OUTPUT)
  ipt OUTPUT -t mangle -o tun0 -j MARK --set-mark 3
  # Force marked traffic to default GW
  ip_route_add default via "${GW}" dev "${DEV}" table 3
  ip_rule_add fwmark 3 table 3
  # All packets forced to default GW need to MASQ their source IP
  ipt POSTROUTING -t nat -o "${DEV}" -m mark --mark 3 -j MASQUERADE

  ### Allow some docker traffic to _not go_ via NordVPN (e.g incoming ssh)
  ########################################################################

  # NOTE: Docker on Linux does not use docker-proxy but instead uses netfilter
  # rules to forward traffic from port 22 to port 2222. Need to hack the rules
  # to stop all but legitimate traffic when NordVPN is down.

  # Mark allowed traffic leaving from instances to real Internet. In this case
  # only allow port 2222 (which docker's netfilter rules turn into 22)
  ipt PREROUTING -t mangle -p tcp --sport 2222 -m conntrack --ctstate ESTABLISHED,RELATED -j MARK --set-mark 9
  ip_rule_add fwmark 9 table 3

  ### Prevent traffic from leaving docker-instances when NordVPN is
  ### disconnected.
  #################################################################

  # Stop all docker traffic unless it's marked (e.g. all but SSH)
  # Drop all that are not marked but attempt to leave via real Internet.
  ipt_forward -o "${DEV}" -m mark ! --mark 9 -j DROP
}

# Monitor FW rules and set them again if the rules went missing.
persistent()
{
  DEBUGF "Entering persisent SF-FW mode..."
  while :; do

    sleep 10
    iptables -C OUTPUT -t mangle -o tun0 -j MARK --set-mark 3 2>/dev/null && continue
    WARN 1 "Netfilter rules went missing. Setting them again...."
    echo -e >&2 "--> Try ${CC}systemctl stop sf-fw${CN} to stop the SF Firewall"
    set_all_rules
  done
  exit 251
}

init_vars

# BY DEFAULT do not forward DOCKER traffic unless it's MARKED.
ipt_forward -o "${DEV}" -m mark ! --mark 9 -j DROP

# Start NordVPN or wait until it is fully running.
# NordVPN is configured with autoconnect=on but systemd has no means
# of knowing when NordVPN has connected fully. Thus we trigger
# 'nordvpn connect' - which will block & wait until NordVPN is fully connected.
#nordvpn connect United_Kingdom
#nordvpn connect Onion_Over_VPN

[[ -z $SF_IS_SKIP_NORDVPN ]] && [[ ! "$(nordvpn status)" = *"Status: Connected"* ]] && {
  nordvpn connect || { echo "NordVPN Connection Failed"; exit 248; }
}

set_all_rules

[[ -z $IS_PERSISTENT ]] || persistent
