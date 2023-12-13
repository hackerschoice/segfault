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

run_ban() {
    local interval
    local rx_fn="/sf/config/db/private/${1}"
    local msg_fn="/sf/config/db/private/${2}"
    local regex
    local reason="${rx_fn%.txt}"
    reason="${reason##*rx_}"
    while :; do
        source "$rx_fn" || { sleep 60; continue; }
        for lg in $(lgx "$regex" skiptoken); do
            if [[ -f "$msg_fn" ]]; then
                do_ban "$reason" "$lg" "$(<"$msg_fn"))"
            else
                do_ban "$reason" "$lg" "You got banned. Contact a SysCop to discuss [ERROR: $msg_fn]."
            fi
        done
        sleep "${interval:-360}"
    done
}

run_ban rx_dos.txt banmsg_dos.txt &
run_ban rx_egress.txt banmsg_egress.txt &
run_ban rx_exhaust.txt banmsg_exhaust.txt &

# CTRL-c here will also send a SIGINTR to all child processes (and kill them)
echo "Banhammer started. Press CTRL-c to stop."
read
