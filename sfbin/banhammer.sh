#! /usr/bin/env bash

source /sf/sfbin/funcs_admin.sh >/dev/null || exit

do_ban() {
    echo "[$(date '+%F %H:%M:%S' -u)] Banning $2 [$1]. See /sf/config/db/user/${2}/syscop-ps.txt"
    [[ -n $SF_DEBUG ]] && {
        lgwall "$2" "$3"
        return
    }
    lgban "$2" "$3"
}

do_stop() {
    echo "[$(date '+%F %H:%M:%S' -u)] Stopping $2 [$1]. See /sf/config/db/user/${2}/syscop-ps.txt"
    [[ -n $SF_DEBUG ]] && {
        lgwall "$2" "$3"
        return
    }
    lgstop "$2" "$3"
}

run() {
    local interval
    local rx_fn="/sf/config/db/private/${1}"
    local msg_fn="/sf/config/db/private/${2}"
    local regex
    local reason="${rx_fn%.txt}"
    local cmd="${3:-ban}"
    reason="${reason##*rx_}"
    while :; do
        source "$rx_fn" || { sleep 60; continue; }
        for lg in $(lgx "$regex" skiptoken); do
            if [[ -f "$msg_fn" ]]; then
                "do_${cmd}" "$reason" "$lg" "$(<"$msg_fn"))"
            else
                "do_${cmd}" "$reason" "$lg" "Your server was stopped. Contact a SysCop to discuss [ERROR: $msg_fn]."
            fi
        done
        sleep "${interval:-360}"
    done
}

run rx_dos.txt banmsg_dos.txt ban &
run rx_egress.txt banmsg_egress.txt ban &
run rx_exhaust.txt stop_exhaust.txt stop &

# CTRL-c here will also send a SIGINTR to all child processes (and kill them)
echo "Banhammer started. Press CTRL-c to stop."
read -r -d '' _ </dev/tty
