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

source "${BASEDIR}/log/vpn_status"
source "${BASEDIR}/config"

[[ -z $IS_VPN_CONNECTED ]] && VPN_DST="${CR}NOT CONNECTED${CN}" || VPN_DST="${CDG}${VPN_COUNTRY:-UNKNOWN}${CN}"

echo -e "VPN connected to: ${VPN_DST}"
echo -e "DNS over HTTPS  : ${CDG}Cloudflare${CN}"
echo -e "TOR Proxy       : ${CDG}172.24.0.4:9050${CN}"
echo -e "Connect with    : ${CDC}ssh -o \"SetEnv LID=${LID}\" user@${L0PHT_SERVER_DIRECT:-UNKNOWN}${CN}"
echo -e "Non-Root        : ${CDC}su user${CN}"
echo -e "${CW}Join us on Telegram: https://t.me/thcorg${CN}"
