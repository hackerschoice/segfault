#! /usr/bin/env bash

source /sf/sfbin/funcs.sh >/dev/null || exit
SF_NOINIT=1 source /sf/sfbin/funcs_admin.sh >/dev/null || exit

cb_match() {
    local lg="${1}"
    local reason="${2}"
    local action="${3:-stop}"
    local str
    local m="${BASH_REMATCH[0]}"

	local geoip ip hn age_str t_created cip
	# sets age_str, ip, hn, cip, geoip
	_sf_loaduserinfo "${lg}"
	ip="${ip}                      "
	ip="${ip:0:16}"

    echo -e "[$(date '+%F %H:%M:%S' -u)] ${CDY}${action}${CN} ${CDM}${lg} ${CDB}${hn} ${CG}${ip} ${CF}${cip}${CDG}${geoip}${CN}"
    # Get one line before and after the match
    str="$(echo "$SF_G_PS" | grep -1 -F "${m}")"
    # Highlight the matched string in red
    echo $'\e[2m'"${str//${m}/$'\e[1;31m\e[2m'${m}$'\e[0m\e[2m'}"$'\e[0m'
    echo -e "=> ${CDC}/sf/config/db/user/${lg}/syscop-ps.txt${CN}"

    local msg="Your server received a ${action} (reason: ${reason}). Contact a SysCop to discuss."
    [ -f "/sf/config/db/private/msg_${reason}.txt" ] && msg="$(<"/sf/config/db/private/msg_${reason}.txt")"
    msg+=$'\n'"LOG $SF_HOST:/sf/config/db/user/${lg}/syscop-ps.txt"
    [[ -n $SF_DEBUG ]] && {
        SF_NOINIT=1 lgwall "$1" "${msg}"
        return
    }
    SF_NOINIT=1 "lg${action}" "$lg" "${msg}" >/dev/null
}

# type action
# egress stop
# - load rx_egress.txt 
# - error msg is msg_egress.txt
# - action is lgstop
run() {
    local interval
    local reason="${1}"
    local rx_fn="/sf/config/db/private/rx_${1}.txt"
    local regex
    local action="${2:-stop}"

    [ -f "$2" ] && msg="$(<"$2")"
    while :; do
        source "$rx_fn" 2>/dev/null || { sleep 60; continue; }
        lgxcall "$regex" skiptoken "cb_match" "$reason" "${action}"
        sleep "${interval:-360}"
    done
}

SF_FQDN="SEGFAULT"
[ -f "/sf/config/.env" ] && eval "$(grep ^SF_FQDN= /sf/config/.env)"
SF_HOST="${SF_FQDN%%\.*}"

run dos ban &
# run egress ban &
# run exhaust stop &

# CTRL-c here will also send a SIGINTR to all child processes (and kill them)
echo "Banhammer started. Press CTRL-c to stop."
read -r -d '' _ </dev/tty
