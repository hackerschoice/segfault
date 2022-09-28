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
	local ep_ip

	t="$(wg show "${DEV:-wg0}" endpoints)" && {
		t="${t##*[[:space:]]}"
		ep_ip="${t%:*}"

		geo=$(curl -fsSL --retry 3 --max-time 15 https://ipinfo.io 2>/dev/null) && {
			t=$(echo "$geo" | jq '.country | select(. != null)')
			country="${t//[^A-Za-z]}"
			t=$(echo "$geo" | jq '.city |  select(. != null)')
			city="${t//[^A-Za-z]/}"
			t=$(echo "$geo" | jq '.ip | select(. != null)')
			exit_ip="${t//[^0-9.]/}"
		}
		[[ -z $exit_ip ]] && exit_ip=$(curl -fsSL --max-time 15 ifconfig.me 2>/dev/null)
	} # wg show

	if [[ -z $ep_ip ]]; then
		rm -f "${LOGFNAME}"
	else
		echo -en "\
SFVPN_MY_IP=\"$(ipbydev eth0)\"\n\
SFVPN_EXEC_TS=$(date -u +%s)\n\
SFVPN_ENDPOINT_IP=\"${ep_ip}\"\n\
SFVPN_LOCATION=\"${city:-Artemis}/${country:-Moon}\"\n\
SFVPN_EXIT_IP=\"${exit_ip:-333.1.2.3}\"\n" >"${LOGFNAME}"
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
