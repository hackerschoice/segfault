#! /bin/bash

# CONTEXT: VPN context. Called when WG goes UP or DOWN
# from sfbin/* and mounted into each VPN container

# PARAMETERS: [output filename] [up/down/check/monitor] [interface]

# NOTE:
# POST_UP has all the set environment variables but
# PRE/POST_DOWN is started with all environment variables emptied.
# Is this a WireGuard bug?
# Solution: Save the important variables during POST_UP
if [[ -f /dev/shm/env.txt ]]; then
	source /dev/shm/env.txt
else
	echo -e "SF_DEBUG=\"${SF_DEBUG}\"\n\
SF_REDIS_AUTH=\"${SF_REDIS_AUTH}\"\n\
IS_REDIRECTS_DNS=\"${IS_REDIRECTS_DNS}\"\n\
PROVIDER=\"${PROVIDER}\"\n" >/dev/shm/env.txt
fi

PROVIDER="${PROVIDER,,}"

source /sf/bin/funcs.sh
source /sf/bin/funcs_redis.sh

# From all files update the VPN status file
create_vpn_status()
(
	local exit_ip
	local geoip
	local provider
	local f status_lock tmp

	exec {status_lock}>"${DSTDIR}/.status.lock" || return
	flock "$status_lock" || return

	for f in "${DSTDIR}"/status-*.log; do
		[[ ! -f "${f}" ]] && break
		# shellcheck disable=SC1090
		source "${f}"

		provider+="'${SFVPN_PROVIDER}' "
		exit_ip+="'${SFVPN_EXIT_IP}' "
		geoip+="'${SFVPN_GEOIP}' "
	done

	# Delete vpn_status unless there is at least 1 VPN
	if [[ -z $geoip ]]; then
		rm -f "/config/guest/vpn_status"
		return
	fi

	tmp=$(mktemp /config/guest/.vpn_status.XXXXXX) || return
	echo -en "\
IS_VPN_CONNECTED=1\n\
VPN_GEOIP=(${geoip})\n\
VPN_PROVIDER=(${provider})\n\
VPN_EXIT_IP=(${exit_ip})\n" >"$tmp" && chmod 644 "$tmp" && mv -f "$tmp" /config/guest/vpn_status || { rm -f "$tmp"; return 1; }
)

valid_exit_ip()
{
	local a b c d
	valid_ipport "$1:1" || return 1
	IFS=. read -r a b c d <<<"$1"
	((10#$a > 0 && 10#$a < 224 && 10#$a != 10 && 10#$a != 127)) || return 1
	((10#$a != 100 || 10#$b < 64 || 10#$b > 127)) || return 1
	((10#$a != 169 || 10#$b != 254)) || return 1
	((10#$a != 172 || 10#$b < 16 || 10#$b > 31)) || return 1
	((10#$a != 192 || 10#$b != 168))
}

observed_exit_ip()
{
	[[ "$PROVIDER" == cryptostorm ]] || return 1
	local response ip
	local -a options=(-4 -fsS --noproxy '*' --interface "${DEV}" --connect-timeout 3 --max-time 8)
	# Forwarding belongs to this address, even if browsing uses another exit.
	response=$(curl "${options[@]}" -A Mozilla/5.0 http://10.31.33.7/fwd) || return 1
	ip=$(sed -nE 's/.*A firewall rule will be added to this VPN server \(([0-9.]+)\).*/\1/p' <<<"$response")
	valid_exit_ip "$ip" || return 1
	printf '%s\n' "$ip"
}

check_exit_ip()
(
	[[ "$PROVIDER" == cryptostorm ]] || return 0
	local check_lock candidate ip previous tmp queued
	local SFVPN_EXIT_IP SFVPN_PROVIDER
	exec {check_lock}>"${STATE_PREFIX}.lock" || return
	flock -n "$check_lock" || return 0
	candidate="${STATE_PREFIX}.candidate"
	if [[ ! -f "$LOGFNAME" ]] || ! wg show "$DEV" >/dev/null 2>&1; then
		rm -f "$candidate"
		return 0
	fi
	source "$LOGFNAME"
	[[ "${SFVPN_PROVIDER,,}" == "$PROVIDER" ]] || return 1
	previous="$SFVPN_EXIT_IP"
	ip=$(observed_exit_ip) || { rm -f "$candidate"; return 0; }
	[[ "$ip" == "$previous" ]] && { rm -f "$candidate"; return 0; }
	# Require the same valid new address on two consecutive checks.
	if [[ ! -f "$candidate" || "$(cat "$candidate")" != "$ip" ]]; then
		printf '%s\n' "$ip" >"$candidate"
		return
	fi

	tmp=$(mktemp "${STATE_PREFIX}.XXXXXX") || return
	sed "s/^SFVPN_EXIT_IP=.*/SFVPN_EXIT_IP=\"${ip}\"/" "$LOGFNAME" >"$tmp" || { rm -f "$tmp"; return 1; }
	chmod 644 "$tmp" || { rm -f "$tmp"; return 1; }
	# The port manager invalidates this provider's pool and guest assignments,
	# then refills it. Do not run the VPN-up hook or change the tunnel routes.
	queued=$(redr RPUSH portd:cmd "vpnup ${PROVIDER}")
	[[ "$queued" =~ ^[1-9][0-9]*$ ]] || { rm -f "$tmp"; return 1; }
	mv -f "$tmp" "$LOGFNAME" || { rm -f "$tmp"; return 1; }
	create_vpn_status || return
	rm -f "$candidate"
	LOG "VPN" "${PROVIDER} exit IP changed: ${previous} -> ${ip}"
)

monitor_exit_ip()
(
	[[ "$PROVIDER" == cryptostorm ]] || return 0
	local monitor_lock
	exec {monitor_lock}>"${STATE_PREFIX}.monitor.lock" || return
	flock -n "$monitor_lock" || return 0
	while :; do
		check_exit_ip || WARN "${PROVIDER}: exit-IP status update failed"
		sleep 120
	done
)

down()
{
	# NOTE: DEBUGF wont work because stderr is closed during
	# WireGuard PRE_DOWN/POST_DOWN
	[[ -f "${LOGFNAME}" ]] && rm -f "${LOGFNAME}"
	rm -f "${STATE_PREFIX}.candidate"
	create_vpn_status

	ip route del "${NETWORK}" via "${NET_VPN_ROUTER_IP}" 2>/dev/null

	/sf/bin/rportfw.sh fw_delall

	red RPUSH portd:cmd "vpndown ${PROVIDER}"

	[[ "${PROVIDER,,}" == "cryptostorm" ]] && curl -fsSL --retry 1 --max-time 5 http://10.31.33.7/fwd -ddelallfwd=1

	true
}

up()
{
	local t
	local geo
	local exit_ip
	local ep_ip
	local str

	t="$(wg show "${DEV:-wg0}" endpoints)" && {
		t="${t##*[[:space:]]}"
		ep_ip="${t%:*}"

		# First extract Geo Information from wg0.conf file before
		# asking the cloud.
		str=$(grep '# GEOIP=' "/etc/wireguard/wg0.conf")
      	geo="${str:8}"

		str=$(curl -fsSL --retry 3 --max-time 15 https://ipinfo.io 2>/dev/null) && {
			t=$(echo "$str" | jq '.ip | select(. != null)')
			exit_ip="${t//[^0-9.]}"
			[ -z "$geo" ] && {
				local city country
				t=$(echo "$str" | jq '.country | select(. != null)')
				country="${t//[^[:alnum:].-_ \/]}"
				t=$(echo "$str" | jq '.city |  select(. != null)')
				city="${t//[^[:alnum:].-_ \/]}"
				[[ -n $city || -n $country ]] && geo="${city}/${country}"
			}
		}
		# [[ -z $geo ]] && {
			# Query local DB for info
		# }
		[ -z "$exit_ip" ] && exit_ip="$(curl -fsSL --max-time 5 ifconfig.me 2>/dev/null)"
		[ -z "$exit_ip" ] && exit_ip="$(curl -SsfL --max-time 5 https://api.ipify.org 2>/dev/null)"
		[ -z "$exit_ip" ] && exit_ip="$(curl -SsfL --max-time 5 https://icanhazip.com 2>/dev/null)"
		exit_ip="${exit_ip//[^0-9.]}"
		# CryptoStorm's forwarding address also identifies its cached reverse ports.
		if [[ "$PROVIDER" == cryptostorm ]]; then
			t=$(observed_exit_ip) && exit_ip="$t"
		fi
	} # wg show

	if [[ -z $ep_ip ]]; then
		rm -f "${LOGFNAME}"
	else
		local myip
		myip=$(ip addr show | grep inet | grep -F "${NET_VPN_ROUTER_IP%\.*}.")
		myip="${myip#*inet }"
		myip="${myip%%/*}"
		echo -en "\
SFVPN_IS_REDIRECTS_DNS=\"${IS_REDIRECTS_DNS}\"\n\
SFVPN_MY_IP=\"${myip}\"\n\
SFVPN_EXEC_TS=\"$(date -u +%s)\"\n\
SFVPN_ENDPOINT_IP=\"${ep_ip}\"\n\
SFVPN_GEOIP=\"${geo:-Artemis}\"\n\
SFVPN_PROVIDER=\"${PROVIDER}\"
SFVPN_EXIT_IP=\"${exit_ip:-333.1.2.3}\"\n" >"${LOGFNAME}"
	fi

	create_vpn_status

	# ip route del "${NETWORK}" 2>/dev/null
	ip route add "${NETWORK}" via "${NET_VPN_ROUTER_IP}" 2>/dev/null

	# Delete all old port forwards.
	[[ "${PROVIDER,,}" == "cryptostorm" ]] && curl -fsSL --retry 3 --max-time 10 http://10.31.33.7/fwd -ddelallfwd=1 >/dev/null

	red RPUSH portd:cmd "vpnup ${PROVIDER}"
	true
}

[[ -z $2 ]] && exit 254

export REDISCLI_AUTH="${SF_REDIS_AUTH}"

LOGFNAME="$1"
OP="$2"
DEV="${3:-wg0}"
DSTDIR="$(dirname "${LOGFNAME}")"
STATE_PREFIX="${DSTDIR}/.${LOGFNAME##*/}"

[[ ! -d "${DSTDIR}" ]] && { umask 077; mkdir -p "${DSTDIR}"; }
if [[ "$OP" == up || "$OP" == down ]]; then
	exec {lifecycle_lock}>"${STATE_PREFIX}.lock" || exit
	flock "$lifecycle_lock" || exit
	rm -f "${STATE_PREFIX}.candidate"
fi
[[ "$OP" == "down" ]] && { down; exit; }
[[ "$OP" == "check" ]] && { check_exit_ip; exit; }
[[ "$OP" == "monitor" ]] && { monitor_exit_ip; exit; }

# This is executed by PostUp. wg-quick (in run.sh) will wait until this has finished executing.
# - Make sure VPN is up correctly and we can get geo-ip infos.
# - wg_up in "run" will go into a forever-loop to check VPN status.
source /check_vpn.sh
wait_for_handshake "${DEV}" || { echo -e "Handshake did not complete"; exit 255; }

[ "$OP" = "up" ] && {
	# wg_route_up "${DEV}"
	check_vpn "${PROVIDER}" "${DEV}" || { echo -e "VPN Check failed"; exit 255; }
	[ "${PROVIDER,,}" = "cryptostorm" ] && {
		# Check if internal CS systems are operational:
		res="$(curl -fs --retry 3 --max-time 10 http://10.31.33.7/fwd 2>/dev/null)" || unset res
		[ -z "$res" ] && { echo -e "CS PortForward down"; exit 255; }
	}

	up
	exit
}

echo >&2 "OP=${OP}"
echo >&2 "Usage: [output filename] [up/down/check/monitor] [interface]"
exit 255
