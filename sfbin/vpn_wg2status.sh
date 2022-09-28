#! /bin/bash

# [output filename] [post_up/post_down] [interface]



# From all files update the VPN status file
create_vpn_status()
{
	local loc
	local exit_ip

	loc=()
	exit_ip=()
	for f in "${DSTDIR}"/status-*.log; do
		[[ ! -f "${f}" ]] && break
		# shellcheck disable=SC1090
		source "${f}"
		# loc+=("${SFVPN_LOCATION}[$SFVPN_EXIT_IP]")
		loc+=("${SFVPN_LOCATION}")
		exit_ip+=("$SFVPN_EXIT_IP")
	done

	# Delete vpn_status unless there is at least 1 VPN
	if [[ ${#loc[@]} -eq 0 ]]; then
		rm -f "/config/guest/vpn_status"
		return
	fi

	echo -en "\
IS_VPN_CONNECTED=1\n\
VPN_LOCATION=\"${loc[*]}\"\n\
VPN_EXIT_IP=\"${exit_ip[*]}\"\n" >"/config/guest/vpn_status"
}

post_down()
{
	[[ -f "${LOGFNAME}" ]] && rm -f "${LOGFNAME}"
	
	create_vpn_status
}

post_up()
{
	local t
	local country
	local geo
	local city
	local exit_ip

	t="$(wg show "${DEV:-wg0}" endpoints)" && {
		t="${t##*[[:space:]]}"
		EP_IP="${t%:*}"

		geo=$(curl https://ipinfo.io 2>/dev/null) && {
			t=$(echo "$geo" | jq .country)
			country="${t//[^A-Za-z]}"
			t=$(echo "$geo" | jq .city)
			city="${t//[^A-Za-z]/}"
			t=$(echo "$geo" | jq .ip)
			exit_ip="${t//[^0-9.]/}"
		}
	} # wg show

	if [[ -z $EP_IP ]]; then
		rm -f "${LOGFNAME}"
	else
		echo -en "\
SFVPN_MY_IP=\"$(ipbydev eth0)\"\n\
SFVPN_EXEC_TS=$(date -u +%s)\n\
SFVPN_ENDPOINT_IP=\"${EP_IP}\"\n\
SFVPN_LOCATION=\"${city}/${country}\"\n\
SFVPN_EXIT_IP=\"${exit_ip}\"\n" >"${LOGFNAME}"
	fi

	create_vpn_status
}

[[ -z $2 ]] && exit 254

LOGFNAME="$1"
OP="$2"
DEV="${3:-wg0}"
PROVIDER="${4}"
DSTDIR="$(dirname "${LOGFNAME}")"

[[ ! -d "${DSTDIR}" ]] && { umask 077; mkdir -p "${DSTDIR}"; }
[[ "$OP" == "post_down" ]] && { post_down; exit; }

source /check_vpn.sh
wait_for_handshake "${DEV}" || { echo -e "Handshake did not complete"; exit 255; }

check_vpn "${PROVIDER}" || { echo -e "VPN Check failed"; exit 255; }

[[ "$OP" == "post_up" ]] && { post_up; exit; }

echo >&2 "OP=${OP}"
echo >&2 "Usage: [output filename] [post_up/post_down] [interface] <mullvad/cryptostorm>"
exit 255
