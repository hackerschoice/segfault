#! /usr/bin/env bash

SF_BASEDIR="${SF_BASEDIR:-/sf}"
SF_DATADIR="${SF_DATADIR:-${SF_BASEDIR}/data}"
BINDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${BINDIR}/funcs.sh" || exit 1
SF_NOINIT=1
source "${BINDIR}/funcs_admin.sh" || exit 1

# Keep an unavailable Docker daemon from holding a scan indefinitely.
docker() { command timeout --kill-after=5 30 docker "$@"; }

cb_match()
{
    local lg="$1" reason="$2" action="$3" m="$4" str
    local geoip ip hn age_str t_created cip
    _sf_loaduserinfo "$lg"
    printf '[%s] %s %s %s %s\n' "$(date -u '+%F %T')" "$action" "$lg" "$hn" "$ip"
    str="$(printf '%s\n' "$SF_G_PS" | grep -F -C 1 -- "$m")"
    printf '%s\n' "$str"
    local msg="Your server received a ${action} (reason: ${reason}). Contact a SysCop to discuss."
    [[ -f "${_sf_dbdir}/private/msg_${reason}.txt" ]] && msg="$(<"${_sf_dbdir}/private/msg_${reason}.txt")"
    msg+=$'\n'"LOG ${SF_HOST}:${_sf_dbdir}/user/${lg}/syscop-ps.txt"
    [[ $stopping -eq 1 ]] && return 0
    if [[ -n $SF_DEBUG ]]; then
        lgwall "$lg" "$msg"
    else
        "lg${action}" "$lg" "$msg"
    fi
}

declare -A next_due rule_regex rule_status
groups=(dos egress exhaust)
stopping=0

rule_state()
{
    local group="$1" state="$2"
    [[ ${rule_status[$group]} == "$state" ]] && return
    rule_status[$group]="$state"
    printf '[%s] %s: %s\n' "$(date -u '+%F %T')" "$group" "$state" >&2
}

load_rule()
{
    local group="$1" now="$2" regex= interval=360 rc
    local fn="${_sf_dbdir}/private/rx_${group}.txt"
    unset 'rule_regex[$group]'
    next_due[$group]=$((now + 60))
    if [[ ! -f $fn ]]; then
        rule_state "$group" "waiting for rule file"
        return 1
    fi
    if ! source "$fn"; then
        rule_state "$group" "cannot load rule file"
        return 1
    fi
    if [[ -z $regex || ! $interval =~ ^[1-9][0-9]{0,8}$ ]]; then
        rule_state "$group" "invalid regex or interval"
        return 1
    fi
    [[ "" =~ $regex ]]
    rc=$?
    if [[ $rc -ne 1 ]]; then
        rule_state "$group" "regex is invalid or matches empty text"
        return 1
    fi
    rule_regex[$group]="$regex"
    next_due[$group]=$((now + interval))
    rule_state "$group" "active"
}

scan()
{
    local now names lg group action
    local -a due=()
    now=$(date -u +%s)
    _sf_now=$now
    for group in "${groups[@]}"; do
        [[ $now -lt ${next_due[$group]:-0} ]] && continue
        load_rule "$group" "$now" && due+=("$group")
    done
    [[ ${#due[@]} -eq 0 || $stopping -eq 1 ]] && return 0
    names=$(docker ps --format '{{.Names}}' --filter 'name=^lg-') || {
        echo >&2 "Cannot list guests; scan skipped."
        return 1
    }
    while IFS= read -r lg; do
        [[ $stopping -eq 1 ]] && break
        [[ $lg != lg-* || -e "${_sf_dbdir}/user/${lg}/token" || -L "${_sf_dbdir}/user/${lg}/token" ]] && continue
        SF_G_PS=$(docker top "$lg" -e -o pid,ppid,%cpu,rss,start_time,exe,comm,cmd) || continue
        SF_G_PS_LID=$lg
        [[ -z $SF_G_PS || $stopping -eq 1 ]] && continue
        # Ban rules precede stop rules; at most one action per guest per scan.
        for group in "${due[@]}"; do
            if [[ "$SF_G_PS"$'\n' =~ ${rule_regex[$group]} ]]; then
                action=ban
                [[ $group == exhaust ]] && action=stop
                cb_match "$lg" "$group" "$action" "${BASH_REMATCH[0]}" ||
                    echo >&2 "Failed to $action $lg for $group."
                break
            fi
        done
    done <<<"$names"
    unset SF_G_PS SF_G_PS_LID
}

stop()
{
    stopping=1
    [[ -n ${sleep_pid:-} ]] && kill "$sleep_pid" 2>/dev/null
}
trap stop TERM INT

[[ $# -eq 0 || ( $# -eq 1 && $1 == --once ) ]] || { echo >&2 "Usage: $0 [--once]"; exit 2; }
state_dir="${SF_DATADIR}/maintenance"
mkdir -p "$state_dir" || exit 1
exec 9>"${state_dir}/banhammer.lock"
flock -n 9 || { echo >&2 "Banhammer is already running."; exit 0; }

SF_HOST="${SF_FQDN:-SEGFAULT}"
[[ -f "${SF_BASEDIR}/config/.env" && -z $SF_FQDN ]] &&
    SF_HOST="$(sed -n 's/^SF_FQDN=//p' "${SF_BASEDIR}/config/.env" | head -n 1)"
SF_HOST="${SF_HOST:-SEGFAULT}"
SF_HOST="${SF_HOST%%.*}"
_sf_region=$SF_HOST
echo "Banhammer started: dos=ban, egress=ban, exhaust=stop."
while [[ $stopping -eq 0 ]]; do
    scan
    [[ $1 == --once || $stopping -eq 1 ]] && break
    sleep 5 & sleep_pid=$!
    wait "$sleep_pid"
    unset sleep_pid
done
exit 0
