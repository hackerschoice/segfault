#! /bin/bash

_sf_load_api_key() {
    local name="${1:?}"
    eval "[[ -n \$${name}_TOKEN ]] && return"
    [[ -f "${HOME}/.config/${name}/api_key" ]] && {
        eval "${name}_TOKEN"=$(<"${HOME}/.config/${name}/api_key")
        return
    }
    eval "[[ -n \$${name}_TOKEN_NOT_FOUND_DID_WARN ]]" && return
    eval "${name}_TOKEN_NOT_FOUND_DID_WARN"=1
    echo -e >&2 "${CRY}WARN${CN}: Token ${CDY}~/.config/${name}/api_key${CN} not found"
}

io() {
    local arr=()
    _sf_load_api_key "ipinfo"

    [[ -n $ipinfo_TOKEN ]] && arr+=("-H" "Authorization: Bearer $ipinfo_TOKEN")
    curl -m10 -fsSL "${arr[@]}" "https://ipinfo.io/${1:?}"
}

io2() {
    local arr=()
    _sf_load_api_key "ipinfo"

    [[ -n $ipinfo_TOKEN ]] && arr+=("-H" "Authorization: Bearer $ipinfo_TOKEN")
    curl -m10 -fsSL "${arr[@]}" "https://host.io/api/domains/ip/${1:?}"
}

dns() {
    _sf_load_api_key "dnsdb"

    [[ -n $dnsdb_TOKEN ]] || return
    curl -m10 -fsSL -H "X-API-Key: $dnsdb_TOKEN" -H "Accept: application/json" "https://api.dnsdb.info/lookup/rdata/ip/${1:?}?limit=20&humantime=t"
}

ptr() {
    io "${1:?}"
    io2 "$1"
    shodan host "$1" 2>/dev/null
    dns "$1"
    host "$1"
}