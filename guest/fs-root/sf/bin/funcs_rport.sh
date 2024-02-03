
_sf_rport_load() {
    [[ ! -f "$2" ]] && return 255
    eval "${1}=$(<"$2")"
}

sf_rport_load_all() {
    [[ ! -f /config/self/reverse_port ]] && curl sf/port
    _sf_rport_load rport /config/self/reverse_port || { echo -e >&2 "No reverse port found. Try ${CC}curl sf/port${CN}."; return 255; }
    _sf_rport_load rip /config/self/reverse_ip || { echo -e >&2 "No reverse port found. Try ${CC}curl sf/port${CN}."; return 255; }
}
