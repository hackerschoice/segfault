
_sf_rport_load() {
    [ ! -f "$2" ] && return 255
    eval "[ -n \"\${$1}\" ] && { echo -e >&2 \"Using already set ${CDY}${1}=\${$1}${CN}. Type ${CDC}unset ${1}${CN} to undo.\"; return 0; }"
    eval "${1}=$(<"$2")"
}

# set RPORT and RIP
sf_rport_load_all() {
    [ -z "$RPORT" ] && [ -z "$RIP" ] && [ ! -f /config/self/reverse_port ] && curl sf/port
    _sf_rport_load RPORT /config/self/reverse_port || { echo -e >&2 "No reverse port found. Try ${CC}curl sf/port${CN}."; return 255; }
    _sf_rport_load RIP /config/self/reverse_ip || { echo -e >&2 "No reverse port found. Try ${CC}curl sf/port${CN}."; return 255; }
}
