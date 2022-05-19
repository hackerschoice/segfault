#! /bin/bash

# Segfault monitor script to update VPN_STATUS and 

BASEDIR="$(cd "$(dirname "${0}/")" || exit; pwd)"
source "${BASEDIR}/funcs" || exit 255

[[ -z $SF_BASEDIR ]] && ERREXIT 255 "SF_BASEDIR= not set"
command -v nordvpn >/dev/null || ERREXIT 254 "Not found: nordvpn"

VPN_LOG_FILE="${SF_BASEDIR}/guest/sf-guest/log/vpn_status"
# Delete old/stale file
[[ -e "${VPN_LOG_FILE}" ]] && rm -f "${VPN_LOG_FILE}"

while :; do
	unset out
	unset server_ip
	unset country
	IFS=$'\n' status=( $(nordvpn status) )
	[[ "${status[*]}" = *"Status: Connected"* ]] && {
		# CONNECTED
		for x in "${status[@]}"; do
			[[ "$x" =~ ^'Country: ' ]] && country="${x:9}" && continue
			[[ "$x" =~ ^'Server IP: ' ]] && server_ip="${x:11}" && continue
			[[ "$x" =~ ^'Current server: ' ]] && server="${x:16}" && continue
		done

		# DEBUGF "Uptime: $vpn_uptime"
		out="\
IS_VPN_CONNECTED=1
VPN_COUNTRY=\"${country}\"
VPN_SERVER=\"${server}\"
VPN_SERVER_IP=\"${server_ip}\""
	} # CONNECTED

	if [[ ! -e "${VPN_LOG_FILE}" ]] || [[ "$out" != "$old" ]]; then
		# Find out out external IP address
		myip=$(docker exec sf-tor curl -s ifconfig.me) || unset myip

		echo "${country:-NOT CONNECTED} (${myip:-UNKNOWN}) [${server}]"
		echo "\
${out}
VPN_IP=\"${myip:-<FAILED.TO.GET.IP>}\"" >"${VPN_LOG_FILE}"

		# In order to stop polling 'ifconfig.me' we rely on NordVPN's VPN_SERVER to
		# change and only then call 'curl ifconfig.me'.
		# 
		# It may have happened that 'curl ifconfig.me' failed (sf-tor not running or
		# ifconfig.me down). In this case keep trying every 10 seconds.
		# Only update if manage to get EXIT IP. 
		[[ -z $myip ]] || old="$out"
	fi

	sleep 10
done
