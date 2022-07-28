#! /bin/bash

# CY="\033[1;33m" # yellow
# CG="\033[1;32m" # green
CR="\033[1;31m" # red
# CC="\033[1;36m" # cyan
# CM="\033[1;35m" # magenta
# CW="\033[1;37m" # white
CF="\033[2m"    # faint
CN="\033[0m"    # none

# CBG="\033[42;1m" # Background Green

# night-mode
CDY="\033[0;33m" # yellow
CDG="\033[0;32m" # green
# CDR="\033[0;31m" # red
CDC="\033[0;36m" # cyan
# CDM="\033[0;35m" # magenta

# BINDIR="$(cd "$(dirname "${0}")" || exit; pwd)"

# shellcheck disable=SC1091
source "/sf/run/vpn/vpn_status" 2>/dev/null

[[ -z $IS_VPN_CONNECTED ]] && VPN_DST="${CR}TOR ${CF}(no VPN)${CN}" || VPN_DST="${CDG}${VPN_EXIT_IP} (${VPN_LOCATION:-UNKNOWN})${CN}"
YOURIP="${SSH_CONNECTION%%[[:space:]]*}"

echo -e "\
Your workstation  : ${CDY}${YOURIP:-UNKNOWN}${CN}
VPN Exit Node     : ${VPN_DST}
DNS over HTTPS    : ${CDG}Cloudflare${CN}
TOR Proxy         : ${CDG}${SF_TOR:-UNKNOWN}:9050${CN}
Persistent storage: ${CDC}/sec ${CF}(encrypted)${CN}"
[[ -e /config/onion_hostname-80 ]] && {
	echo -e "\
Your Web Page     : ${CDC}http://$(cat /config/onion_hostname-80)/${SF_HOSTNAME,,}/${CN}"
}
[[ -e /config/onion_hostname-22 ]] && {
	echo -e "\
SSH (TOR)         : ${CDC}torsocks ssh -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" \\ \n\
                       ${SF_USER:-UNKNOWN}@$(cat /config/onion_hostname-22)${CN}"
}
[[ -e /sf/run/gsnc-access-22.txt ]] && {
	echo -e "\
SSH (gsocket)     : ${CDC}gsocket -s $(cat /sf/run/gsnc-access-22.txt) ssh -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" \\ \n\
                       ${SF_USER:-UNKNOWN}@${SF_FQDN%.*}.gsocket${CN}"
}

[[ -n $SF_SSH_PORT ]] && PORTSTR="-p${SF_SSH_PORT} "
echo -e "\
SSH               : ${CDC}ssh -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" ${PORTSTR}${SF_USER:-UNKNOWN}@${SF_FQDN:-UNKNOWN}${CN}"
