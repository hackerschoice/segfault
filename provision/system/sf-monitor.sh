#! /bin/bash

BASEDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
source "${BASEDIR}/funcs" || exit 255

# Set our fw rules in case some do-da admin takes them out...
IS_FW_MONITOR=1

[[ -z $SF_BASEDIR ]] && ERREXIT 255 "SF_BASEFDIR= not set"
command -v nordvpn >/dev/null || ERREXIT 254 "Not found: nordvpn"
command -v iptables >/dev/null || { WARN 1 "iptables not found. Wont monitor iptables."; unset IS_FW_MONITOR; }
[[ -e "${SF_BASEDIR}"/system/sf-fw.sh ]] || { WARN 2"system/sf-fw.sh not found. Won't monitor iptables."; unset IS_FW_MONITOR; }

VPN_LOG_FILE="${SF_BASEDIR}/guest/sf-guest/log/vpn_status"

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
		done

		out="\
IS_VPN_CONNECTED=1
VPN_COUNTRY=\"${country}\"
VPN_SERVER_IP=\"${server_ip}\""
	} # CONNECTED

	if [[ ! -e "${VPN_LOG_FILE}" ]] || [[ "$out" != "$old" ]]; then
		# Find out out external IP address
		myip=$(docker exec sf-tor curl -s ifconfig.me) || unset myip

		echo "${country:-NOT CONNECTED} (${myip:-UNKNOWN})"
		echo "\
${out}
VPN_IP=\"${myip}\"" >"${VPN_LOG_FILE}"

		old="$out"
	fi

	sleep 10

	# Check if iptable rules are still valid
	# Do this after the 'sleep' to prevent this script from setting FW rules
	# before sf-fw.service had a chance.
	[[ -n $IS_FW_MONITOR ]] && {
		"${SF_BASEDIR}/system/sf-fw.sh"
	}
done
