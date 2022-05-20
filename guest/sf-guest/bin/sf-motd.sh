#! /bin/bash

CY="\033[1;33m" # yellow
CG="\033[1;32m" # green
CR="\033[1;31m" # red
CC="\033[1;36m" # cyan
CM="\033[1;35m" # magenta
CW="\033[1;37m" # white
CF="\033[2m"    # faint
CN="\033[0m"    # none

CBG="\033[42;1m" # Background Green

# night-mode
CDY="\033[0;33m" # yellow
CDG="\033[0;32m" # green
CDR="\033[0;31m" # red
CDC="\033[0;36m" # cyan
CDM="\033[0;35m" # magenta

BINDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
BASEDIR="$(cd "${BINDIR}/.." || exit; pwd)"

source "${BASEDIR}/log/vpn_status" 2>/dev/null

[[ -z $IS_VPN_CONNECTED ]] && VPN_DST="${CR}NOT CONNECTED${CN}" || VPN_DST="${CDG}${VPN_IP} (${VPN_COUNTRY:-UNKNOWN})${CN}"
YOURIP=$(echo "$SSH_CONNECTION" | cut -f1 -d" ")

echo -e "\
Your workstation  : ${CDY}${YOURIP:-UNKNOWN}${CN}
VPN Exit Node     : ${VPN_DST}
DNS over HTTPS    : ${CDG}Cloudflare${CN}
TOR Proxy         : ${CDG}172.24.0.4:9050${CN}
Persistent storage: ${CDC}/sec ${CF}(encrypted)${CN}"
[[ -e /config/onion_hostname ]] && {
	echo -e "\
Your Web Page     : ${CDC}http://$(cat /config/onion_hostname)/${SF_HOSTNAME,,}${CN}"
}
echo -e "\
Access with       : ${CDC}ssh -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" ${SF_USER:-UNKNOWN}@${SF_FQDN:-UNKNOWN}${CN}"
