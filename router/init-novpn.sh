#! /bin/bash


[[ -z $SF_DIRECT ]] && {
    rm -f "/sf/run/vpn/status-novpn.log" 2>/dev/null
    rm -f "/sf/run/vpn/vpn_status.direct" 2>/dev/null
    exit 0
}

source "/sf/bin/funcs.sh"
source "/sf/bin/funcs_net.sh"

# [[ -z $geo ]] && geo=$(curl -fsSL --retry 3 --max-time 15 https://ipinfo.io 2>/dev/null) && {
#     local city
#     local geo
#     t=$(echo "$geo" | jq '.country | select(. != null)')
#     country="${t//[^[:alnum:].-_ \/]}"
#     t=$(echo "$geo" | jq '.city |  select(. != null)')
#     city="${t//[^[:alnum:].-_ \/]}"
#     t=$(echo "$geo" | jq '.ip | select(. != null)')
#     exit_ip="${t//[^0-9.]}"
#     geo="${city}/${country}"
# }
# # [[ -z $geo ]] && {
#     # Query local DB for info
# # }
# [[ -z $exit_ip ]] && exit_ip=$(curl -fsSL --max-time 15 ifconfig.me 2>/dev/null)

LOGFNAME="/sf/run/vpn/status-novpn.log"
PROVIDER="DIRECT"
		echo -en "\
SFVPN_MY_IP=\"${SF_NOVPN_IP}\"\n\
SFVPN_EXEC_TS=\"$(date -u +%s)\"\n\
SFVPN_ENDPOINT_IP=\"${ep_ip}\"\n\
SFVPN_GEOIP=\"${geo:-Artemis}\"\n\
SFVPN_PROVIDER=\"${PROVIDER}\"
SFVPN_EXIT_IP=\"${exit_ip:-333.1.2.3}\"\n" >"${LOGFNAME}"

touch "/config/guest/vpn_status.direct"

ip route add "${NET_LG}" via "${NET_VPN_ROUTER_IP}"
# All outgoing needs to be MASQ'ed.
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Keep 1 process alive so that we can use `nsenter` to enter this network namespace
# [[ -z $SF_DEBUG ]] && exit 0
exec -a '[novpn-sleep]' sleep infinity
