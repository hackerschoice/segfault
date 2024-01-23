# TODO:
# 1. what happens if I create wgEXIT and vpnEXIT?
# 1. It might be better to start the openvpn in an isolated container, then move
#    the tun0 interface to the user's container. This way we would not need
#    to sanitize the config files.

[[ -z "$SF_GUEST_MTU" ]] && SF_GUEST_MTU=$((SF_HOST_MTU - 80))

cmd_ovpn_help() {
    	echo -en "\
Use ${C}curl sf/ovpn/up -d config=\"\$(pwd)/openvpn.conf\"${N}
Use ${C}curl sf/ovpn/up -d config=\"\$(pwd)/openvpn.conf\" -d user=username -d pass=password${N}
Use ${C}curl sf/ovpn/up -d config=\"\$(pwd)/openvpn.conf\" -d keypass=password${N}
Use ${C}curl sf/ovpn/up -d config=\"\$(pwd)/openvpn.conf\" -d route=8.0.0.0/20 -d route=172.16.0.0/22${N}
Use ${C}curl sf/ovpn/show${N} for status.
Use ${C}curl sf/ovpn/down${N} to disconnect."
    exit;
}

# cat a file from user's container.
user_cat() {
    local IFS
    local fn="$1"
    local max="$2"
    local -

    set -o pipefail
    [[ ${fn:0:1} != "/" ]] && fn="${VPN_LG_BASE}/${fn}"
    ## Reading a file from the user. Be careful.
    fn="${fn//[^[:alnum:]-_+\/.]}"

    timeout 2 docker exec -u0 "lg-${LID:?}" cat -- "${fn}" 2>&1 | dd bs=1k count="${max:-16}" 2>/dev/null
}

vpn_read_config() {
    local IFS
    local config
    local arr
    local -
    local is_read_ca
    local is_read_key
    local is_read_cert
    local is_read_tls
    local err
    local LC_ALL=C

    # Set defaults
    VPN_CFG_PROTO="udp"
    VPN_CFG_PROTO_SIZE=8
    VPN_CFG_REMOTE_PORT="1194"

    # Find out base directory.
    VPN_LG_BASE="${R_CONFIG%/*}"

    set -f
    IFS=$'\n' config=($(user_cat "$R_CONFIG" 16)) || BAIL "${config[*]}"

    # Extract only those configuration values we deem safe.
    for l in "${config[@]}"; do
        l="${l//[^[:print:]}"
        key="${l%% *}"

        ### CA
        [[ "${key,,}" == "<ca>" ]] && [[ -z "$VPN_CFG_CA" ]] && {
            is_read_ca=1
            continue
        }
        [[ -n "$is_read_ca" ]] && {
            [[ "${key,,}" == "</ca>" ]] && { unset is_read_ca; continue; }
            VPN_CFG_CA+="$l"$'\n'
            continue
        }

        ### KEY
        [[ "${key,,}" == "<key>" ]] && [[ -z "$VPN_CFG_KEY" ]] && {
            is_read_key=1
            continue
        }
        [[ -n "$is_read_key" ]] && {
            [[ "${key,,}" == "</key>" ]] && { unset is_read_key; continue; }
            VPN_CFG_KEY+="$l"$'\n'
            continue;
        }

        ### TLS-AUTH
        [[ "${key,,}" == "<tls-auth>" ]] && [[ -z "$VPN_CFG_TLS" ]] && {
            is_read_tls=1
            continue
        }
        [[ -n "$is_read_tls" ]] && {
            [[ "${key,,}" == "</tls-auth>" ]] && { unset is_read_tls; continue; }
            VPN_CFG_TLS+="$l"$'\n'
            continue;
        }

        ### CERT
        [[ "${key,,}" == "<cert>" ]] && [[ -z "$VPN_CFG_CERT" ]] && {
            is_read_cert=1
            continue
        }
        [[ -n "$is_read_cert" ]] && {
            [[ "${key,,}" == "</cert>" ]] && { unset is_read_key; continue; }
            [[ $is_read_cert -le 1 ]] && [[ "${l:0:5}" != "-----" ]] && continue
            is_read_cert=2
            VPN_CFG_CERT+="$l"$'\n'
            continue;
        }

        [[ ${key} == proto ]] && {
            str="${l##* }"
            [[ ${str,,} == "tcp" ]] && VPN_CFG_PROTO="tcp"
            continue
        }

        [[ "${key}" == "auth-user-pass" ]] && [[ -z "$VPN_CFG_PASS" ]] && {
            IFS=" " read -r -a arr <<<"$l"
            # Empty. Should have -dpass and -duser
            [[ ${#arr[@]} -lt 2 ]] && {
                [[ -z "$R_USER" || -z "$R_PASS" ]] && BAIL "Need ${C}-d user=username -d pass=password${N}"
                continue
            }

            IFS=$'\n' arr=($(user_cat "${l##* }")) || BAIL "${arr[*]}"
            VPN_CFG_USER="${arr[0]}"
            VPN_CFG_PASS="${arr[1]}"
            unset arr
            continue
        }
        [[ "${key}" == "ca" ]] && [[ -z "$VPN_CFG_CA" ]] && {
            VPN_CFG_CA="$(user_cat "${l##* }")" || BAIL "$VPN_CFG_CA"
            continue
        }
        [[ "${key}" == "key" ]] && [[ -z "$VPN_CFG_KEY" ]] && {
            VPN_CFG_KEY="$(user_cat "${l##* }")" || BAIL "$VPN_CFG_KEY"
            continue
        }
        [[ "${key}" == "cert" ]] && [[ -z "$VPN_CFG_CERT" ]] && {
            VPN_CFG_CERT="$(user_cat "${l##* }")" || BAIL "$VPN_CFG_CERT"
            continue
        }

        [[ "${key}" == "remote" ]] && [[ -z "$VPN_CFG_REMOTE" ]] && {
            IFS=" " read -r -a arr <<<"$l"
            str="${arr[1]}"
            VPN_CFG_REMOTE="${str//[^[:alnum:]-.]}"
            # BAD if starts with a "."
            [[ ${VPN_CFG_REMOTE:0:1} == "." ]] && unset VPN_CFG_REMOTE  # Cant start with a '.' or '-'
            [[ ${VPN_CFG_REMOTE:0:1} == "-" ]] && unset VPN_CFG_REMOTE  # Cant start with a '.' or '-'
            # sf-master can not resolve. OpenVPN's --up still holds Starting OpenVPN in the user's namespace
            [[ -z "$VPN_CFG_REMOTE" ]] && BAIL "Invalid Remote ('${str}')."
            str="${arr[2]}"
            str="${str//[^0-9]}"
            [[ -n "$str" ]] && VPN_CFG_REMOTE_PORT="$str"
            [[ ${arr[3]} == "tcp"* ]] && VPN_CFG_PROTO="tcp"
            unset arr
            continue
        }

        [[ "${key}" == "route" ]] && [[ ${#R_ROUTE_ARR[@]} -le 0 ]] && {
            #FIXME: Auto-convert route from netmask to cidr and add to R_ROUTE_ARR+=(...)
            echo -e "${ICON_WARN}${R}WARN:${N} Ignoring ${Y}${l}${N}. Used ${C}-d network/cidr${N} instead."
            continue
        }

        [[ "${key}" == "comp-lzo" ]] && {
            VPN_CFG+="comp-lzo"$'\n'
            continue
        }

        [[ "${key}" == "key-direction" ]] && {
            VPN_CFG+="key-direction 1"$'\n'
        }
        [[ "${key}" == "data-ciphers" ]] && {
            str="${l#* }"
            # OpenVPN 2.4 uses "--cipher" but >=2.5 uses "--data-ciphers"
            # VPN_CFG+="data-ciphers ${str//[^[:alnum:]-\:]}"$'\n'
            VPN_CFG_DATA_CIPHERS="${str//[^[:alnum:]-\:]}"
            continue
        }
        [[ "${key}" == "cipher" ]] && {
            str="${l#* }"
            # OpenVPN 2.4 uses "--cipher" but >=2.5 uses "--data-ciphers"
            # VPN_CFG+="data-ciphers ${str//[^[:alnum:]-\:]}"$'\n'
            VPN_CFG_CIPHER="${str//[^[:alnum:]-\:]}"
            continue
        }

        [[ "${key}" == "compress" ]] && {
            str="${l#* }"
            VPN_CFG+="compress ${str//[^[:alnum:]]}"$'\n'
            continue
        }

        [[ "${key}" == "auth" ]] && {
            str="${l#* }"
            VPN_CFG+="auth ${str//[^[:alnum:]]}"$'\n'
            continue
        }

        [[ "${key}" == "tls-cipher" ]] && {
            str="${l#* }"
            VPN_CFG+="tls-cipher ${str//[^[:alnum:]-:@=]}"$'\n'
            continue
        }

        [[ "${key,,}" == "remote-cert-tls" ]] && {
            VPN_CFG+="remote-cert-tls server"$'\n'
            continue
        }
    done

    # Sanitize
    VPN_CFG_CA=${VPN_CFG_CA//[^a-zA-Z0-9+-/$'\n']}
    VPN_CFG_KEY=${VPN_CFG_KEY//[^a-zA-Z0-9+-/$'\n']}
    VPN_CFG_CERT=${VPN_CFG_CERT//[^a-zA-Z0-9+-/$'\n']}
    VPN_CFG_TLS=${VPN_CFG_TLS//[^a-zA-Z0-9+-/$'\n']}
    [[ $VPN_CFG_PROTO == "tcp" ]] && VPN_CFG_PROTO_SIZE=20

    unset err
    [[ -n "$VPN_CFG_CERT" ]] && err=1
    [[ -n "$VPN_CFG_KEY" ]] && ((err++))
    [[ -n "$err" ]] && [[ "$err" -ne 2 ]] && BAIL "CERT and KEY must both be set"
    [[ -z "$VPN_CFG_REMOTE" ]] && BAIL "No REMOTE found."
    [[ -n "$VPN_CFG_KEY" ]] && [[ -n "$VPN_CFG_PASS" ]] && BAIL "Missing key or missing auth-user-pass. Try ${C}-d user=username -d pass=password${N}"
    [[ -z "$VPN_CFG_CA" ]] && BAIL "No CA found. The configuration file is missing a 'ca [file]' or '<ca>' section."
    # Old <2.5 config specifying 'cipher XXX'
    # Odd: To connect a 2.5 client to a 2.4 server I need to set "data-ciphers" and "data-ciphers-fallback"
    [[ -z "$VPN_CFG_DATA_CIPHERS" ]] && VPN_CFG_DATA_CIPHERS="$VPN_CFG_CIPHER"
    [[ -n "$VPN_CFG_DATA_CIPHERS" ]] && VPN_CFG+="data-ciphers ${VPN_CFG_DATA_CIPHERS}"$'\n'
    [[ -n "$VPN_CFG_CIPHER" ]] && VPN_CFG+="data-ciphers-fallback $VPN_CFG_CIPHER"$'\n'

    echo -e "Remote  : ${B}${VPN_CFG_REMOTE} ${F}${VPN_CFG_REMOTE_PORT}/${VPN_CFG_PROTO}${N}"

    return 0
}

vpn_stop() {
    killall "openvpn-${LID:?}" 2>/dev/null
    rm -rf "/tmp/lg-$LID" 2>/dev/null 
    nsenter.u1000 --setuid 0 --setgid 0 -t "${PID:?}" -n ip link delete dev "vpnEXIT" 2>/dev/null
    nsenter.u1000 --setuid 0 --setgid 0 -t "${PID}" -n iptables -F OUTPUT 2>/dev/null
    nsenter.u1000 --setuid 0 --setgid 0 -t "${PID}" -n iptables -F FORWARD 2>/dev/null
}

cmd_ovpn_show() {
    load_lg
    [[ -f "/tmp/lg-${LID:-?}/conf/conn.ovpn" ]] && {
        echo -e "${C}"
        cat "/tmp/lg-${LID}/conf/conn.ovpn"
        echo -en "${N}"
    }
    [[ -f "/tmp/lg-${LID}/ovpn.log" ]] && cat "/tmp/lg-${LID}/ovpn.log"
    exit
}

cmd_ovpn_up() {
    local str
	load_lg
    local link_mtu

    [[ -z "$R_CONFIG" ]] && cmd_ovpn_help
    WG_DEV="vpnEXIT"
    # echo "PID=$PID"

    # Stop if it is already running
    vpn_stop
    # Set default route so that we can reach the remote (in case another VPN was up):
    set_normal_route

    unset VPN_CFG
    VPN_CFG+="client"$'\n'
    VPN_CFG+="dev $WG_DEV"$'\n'
    VPN_CFG+="dev-type tun"$'\n'
    VPN_CFG+="allow-recursive-routing"$'\n'
    VPN_CFG+="single-session"$'\n'
    VPN_CFG+="nobind"$'\n'
    VPN_CFG+="verb 3"$'\n'
    VPN_CFG+="ping 10"$'\n'
    VPN_CFG+="ping-exit 60"$'\n'
    VPN_CFG+="persist-key"$'\n'
    VPN_CFG+="persist-tun"$'\n'
    VPN_CFG+="pull-filter ignore route"$'\n'
    VPN_CFG+="user nobody"$'\n'
    VPN_CFG+="group nogroup"$'\n'

    vpn_read_config || BAIL "Failed to read config file"

    [[ "$VPN_CFG_PROTO" == "udp" ]] && {
        # link-mtu applies to final packets (after encryption and encapsulation) while
        # tun-mtu applies to the unencrypted packets which are about to enter the tun/tap device.
        # link_mtu is bigger than tun_mtu
        # SF_GUEST_MTU is the MTU of the container's eth0 (1420).
        # link_mtu=$((SF_GUEST_MTU - 20 - VPN_CFG_PROTO_SIZE))
        # The documentation says only valid for UDP but if not set and TCP is
        # used then OpenVPN fails handshake (in some cases) with bad/unexpected
        # packet length....
        # Default is 1500 which indicates it's IP + UDP + PAYLOAD (and not what the OpenVPN docs say).
        link_mtu=$((SF_GUEST_MTU))
        VPN_CFG+="link-mtu $link_mtu"$'\n'
        VPN_CFG+="fast-io"$'\n'
        # X - IPv4 - TCP
        # OpenVPN is badly documented. Is this the MSS that is advertised in the TCP header:
        # VPN_CFG+="mssfix $((SF_GUEST_MTU - 20 - 8 - 20 - 20))"$'\n'
        # or does OpenVPN subtract its own size from it and then advertises it?
        # It has to be, right? Because there is no way of us knowing how much header/padding
        # OpenVPN adds (it's not like WireGuard, where things just make sense)
        VPN_CFG+="mssfix $((SF_GUEST_MTU - 20 - 20))"$'\n'
    }
    [[ -n "$VPN_CFG_CA" ]] && VPN_CFG+="<ca>"$'\n'"$VPN_CFG_CA"$'\n'"</ca>"$'\n'
    [[ -n "$VPN_CFG_KEY" ]] && VPN_CFG+="<key>"$'\n'"$VPN_CFG_KEY"$'\n'"</key>"$'\n'
    [[ -n "$VPN_CFG_CERT" ]] && VPN_CFG+="<cert>"$'\n'"$VPN_CFG_CERT"$'\n'"</cert>"$'\n'
    [[ -n "$VPN_CFG_TLS" ]] && VPN_CFG+="<tls-auth>"$'\n'"$VPN_CFG_TLS"$'\n'"</tls-auth>"$'\n'

    VPN_CFG+="proto ${VPN_CFG_PROTO}"$'\n'
    VPN_CFG+="remote ${VPN_CFG_REMOTE} ${VPN_CFG_REMOTE_PORT}"$'\n'

    # HTB
    # OPTS+=(--data-ciphers-fallback AES-128-CBC)
    # Previous versions:
    # OPTS+=(--data-ciphers-fallback BF-CBC)
    # OPTS+=(--cipher AES-256-GCM)

    # OpenVPN's --route remote_host 255.255.255.255 vpn_gateway is not working. Instead
    # we use the --up script to set the static/32 route to the remote VPN PEER:
    unset OPTS
    OPTS+=(--config conn.ovpn)
    OPTS+=(--script-security 2 --up "/sf/bin/ovpn_up.sh" --setenv PID "$PID" --setenv LID "$LID" --setenv SF_NET_LG_ROUTER_IP "$SF_NET_LG_ROUTER_IP")

    # We could create the TUN beforehand but this is no longer needed:
    # nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n ip tuntap add mode tun "${WG_DEV}"
    # the MTU size is overwritten by OpenVPN when it set's the device.
    # nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n ip link set mtu 1233 up dev "${WG_DEV}"

    umask 077
    mkdir -p "/tmp/lg-${LID}/conf"
    cd "/tmp/lg-${LID}/conf" || BAIL "Cant change directory."

    echo -n "$VPN_CFG" >conn.ovpn

    # Force username and password
    [[ -z "$VPN_CFG_PASS" ]] && [[ -z "$R_PASS" ]]
    [[ -n "$R_USER" ]] && VPN_CFG_USER="$R_USER"
    [[ -n "$R_PASS" ]] && VPN_CFG_PASS="$R_PASS"
    [[ -n "$VPN_CFG_PASS" ]] && {
        echo "${VPN_CFG_USER}"$'\n'"${VPN_CFG_PASS}" >userpass.txt
        OPTS+=(--auth-user-pass userpass.txt)
    }
    [[ -n "$R_KEYPASS" ]] && {
        echo "$R_KEYPASS" >keypass.txt
        OPTS+=(--askpass keypass.txt)
    }

    [[ ${#R_ROUTE_ARR[@]} -gt 0 ]] && printf "%s\n" "${R_ROUTE_ARR[@]}" >route

    # echo "${OPTS[@]}"
    # exit
    ln -sf /usr/sbin/openvpn "/tmp/lg-${LID}/conf/openvpn-${LID}"

    # (nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n -C "./openvpn-${LID}" "${OPTS[@]}" &>/dev/null &)
    (nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n -C "./openvpn-${LID}" "${OPTS[@]}" 2>&1 | dd bs=256 count=200 of="/tmp/lg-${LID}/ovpn.log" 2>/dev/nulll &)

    # Block all network traffic beside the one to the OpenVPN PEER (we dont know the IP yet
    # so we block the port instead.
    nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n iptables -I OUTPUT -o eth0 -p "${VPN_CFG_PROTO}" --dport "${VPN_CFG_REMOTE_PORT}" -j ACCEPT
    nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n iptables -I OUTPUT -o eth0 -d "${SF_RPC_IP:?}" -j ACCEPT
    nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n iptables -I OUTPUT -o eth0 -d "${SF_DNS:?}" -j ACCEPT
    nsenter.u1000 --setuid 0 --setgid 0 -t "$PID" -n iptables -A OUTPUT -o eth0 -j DROP

    set_route_pre_up
    str="${R_CONFIG##*/}"
    str="${str%%.*}"
    [[ -z "$str" ]] && str="${VPN_CFG_REMOTE}"
    str="${str^^}"
    echo "(%F{yellow}EXIT:%Bvpn${str:0:16}%b%F{%(#.blue.green)})" >"${LID_PROMPT_FN}"
	echo -en "\
${G}SUCCESS${N}
Use ${C}curl sf/ovpn/show${N} for status.
Use ${C}curl sf/ovpn/down${N} to disconnect.
"
    exit
}

cmd_ovpn_del() {
    load_lg

    vpn_stop
    WG_DEV="vpnEXIT"
    mk_normal_route
    exit
}