#! /bin/bash

#!/usr/bin/with-contenv bash

# Exit without warning if no config is set. The user
# decided not to use this VPN (it's not set in .env)
[[ -z $PRIVATE_KEY ]] && [[ -z $CONFIG ]] && exit 0

source /sf/bin/funcs.sh
## 10-validate
unset is_ok

PROVIDER="${PROVIDER,,}"
[[ -z $PROVIDER ]] && PROVIDER="cryptostorm"

[[ -n $CONFIG ]] && is_ok=1
[[ -z $is_ok ]] && {
    [[ $PROVIDER == "cryptostorm" && -n ADDRESS && -n $SERVER && -n $PRIVATE_KEY && -n $PSK ]] && is_ok=1
    [[ $PROVIDER == "mullvad" && -n ADDRESS && -n $SERVER && -n $PRIVATE_KEY ]] && is_ok=1
    [[ $PROVIDER == "nordvpn" && -n $PRIVATE_KEY ]] && is_ok=1
}

[[ -z $is_ok ]] && {
    if [[ $PROVIDER == "cryptostorm" ]]; then
        echo -e "\
Either set CONFIG= or set ADDRESS=,PSK=,PRIVATE_KEY= and SERVER=\n\
--> Try \`${CDC}docker run --rm --env TOKEN=XXX --entrypoint /getkey.sh hackerschoice/cryptostorm${CN}\`"
    elif [[ $PROVIDER == "mullvad" ]]; then  
        echo -e "\
Either set CONFIG= or set ADDRESS=,PRIVATE_KEY= and SERVER=\n\
--> Get this information from https://mullvad.net/en/account/#/wireguard-config"
    elif [[ $PROVIDER == "nordvpn" ]]; then
        echo -e "\
Either set CONFIG= or set PRIVATE_KEY=\n\
--> Try \`docker run --rm --cap-add=NET_ADMIN -e USER=XXX -e PASS=YYY bubuntux/nordvpn:get_private_key\`\n\
--> or follow this instructions https://forum.openwrt.org/t/instruction-config-nordvpn-wireguard-nordlynx-on-openwrt/89976."
    else
        echo -e "Either set CONFIG= or set ADDRESS=,PRIVATE_KEY= and SERVER="
    fi
    exit 0
}

ip link del dev test 2>/dev/null
if ip link add dev test type wireguard; then
    ip link del dev test
else
    echo "[$(date -Iseconds)] The wireguard module is not active, try \`docker run --rm --cap-add=NET_ADMIN --cap-add=SYS_MODULE -v /lib/modules:/lib/modules\` to install it or follow the proper instructions from https://www.wireguard.com/install/ to manually install it."
    sleep infinity
fi

if ! iptables -L > /dev/null 2>&1; then
    echo "[$(date -Iseconds)] iptables is not functional. Ensure your container config adds --cap-add=NET_ADMIN" 
    sleep infinity
fi

ipt46() {
    iptables "$@"
    ip6tables "$@"
}

# Allow ALL outgoing traffic but only incoming that is part of a tracked connection.
ipt46 -P INPUT DROP
ipt46 -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ipt46 -I INPUT -i lo -j ACCEPT

# ipt46 -P OUTPUT DROP
# ipt46 -A OUTPUT -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

ipt46 -P FORWARD DROP
ipt46 -A FORWARD -o wg+ -j ACCEPT
ipt46 -A FORWARD -i wg+ -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

ipt46 -t nat -A POSTROUTING -o wg+ -j MASQUERADE

SLOWEXIT()
{
  local code
  code="$1"

  shift 1
  echo -e "[${CDR}ERROR${CN}] $*"
  sleep 10
  exit "$code"
}

hn2ip()
{
  local str="${1:?}"

  # Already an IP (does _NOT_ contain any NON-IP characters)
  [[ ! $str =~ [^0-9.] ]] && { echo "$str"; return; }

  str="$(getent ahosts "$str")" || return
  str="${str%% *}"
  [[ "$str" =~ [^0-9.] ]] && return
  echo "${str}"
}

# Create NordVPN list of country ID's.
# curl --silent "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | [.id, .name] | @tsv'
nordvpn_select()
{
  local search
  search="$1"

  iptables -A OUTPUT -o eth0 -p tcp --dport 443 -j ACCEPT
  recommendations=$(curl --max-time 15 --retry 3 -fsSL "https://api.nordvpn.com/v1/servers/recommendations?&filters\[servers_technologies\]\[identifier\]=wireguard_udp&limit=1&${search}")
  iptables -D OUTPUT -o eth0 -p tcp --dport 443 -j ACCEPT
  server=$(echo "${recommendations}" | jq -r '.[0] | del(.services, .technologies)')
  [[ -z ${server} ]] && return
  [[ -z ${PUBLIC_KEY} ]] && PUBLIC_KEY=$(echo "${recommendations}" | jq -r '.[0].technologies[] | select( .identifier == "wireguard_udp" ) | .metadata[] | select( .name == "public_key" ) | .value')
  [[ -z ${END_POINT} ]] && END_POINT=$(echo "${recommendations}" | jq -r '.[0].hostname'):51820
  [[ -z ${EP_IP} ]] && EP_IP=$(echo "${recommendations}" | jq -r '.[0].station')
  [[ -z ${ADDRESS} ]] && ADDRESS="10.5.0.2/32"
  local city
  local country
  city=$(echo "${recommendations}" | jq -r '.[0].locations[0].country.city.name')
  country=$(echo "${recommendations}" | jq -r '.[0].locations[0].country.name')

  # Seattle, WA => Seattle
  city="${city%%,*}"

  # Singapore/Singapore => Singapore
  # Hong Kong/Hong Kong => Hong Kong
  [[ "$country" == "$city" ]] && unset city

  unset GEOIP
  [[ -n $city ]] && GEOIP="${city}/"
  GEOIP+="${country}"
  # Sanitize
  GEOIP="${GEOIP//[^[:alnum:].-_ \/]}"
  
  AUTO_SERVER=$(echo "${recommendations}" | jq -r '.[0].hostname')
}

# auto_select_server <position>
#   Select the nearest server. Position can 0, 1, 2, .. for
#     the 1st, 2nd, 3rd, ...server in the list.
#   Set SERVER, END_POINT, EP_IP and EP_PORT
# Note: Should only be called if WireGuard is DOWN
# Note: I wish CS would provide an API to request nearest server and
#       configuration based on my current IP location. This is mad...
auto_select_server()
{
  local pos
  local str
  local ep
  local name
  local servers
  local hosts
  local ports

  echo "[+] Finding fastest server...."

  [[ "${PROV}" == "nordvpn" ]] && { nordvpn_select; return; }

  # pos="$1"
  # [[ -z $pos ]] && pos=0
  pos=0

  # At the moment END_POINT are all <name>.cstorm.is but this may change...
  # Better read END_POINT from the config file...
  local h
  local p
  for cf in $(cd "/etc/wireguard-${PROV}"; echo *.conf); do
    name="${cf//\.conf/}"
    [[ -z $name ]] && continue

    str="$(grep ^Endpoint "/etc/wireguard-${PROV}/${cf}")"
    str="${str##* }"
    p="${str##*\:}"
    h="${str%%\:*}"
    [[ -z $h ]] && continue
    hosts+=("${h}")
    ports+=("${p}")
    servers+=("${name}")
  done

  # hosts=("atlanta.cstorm.is" "austria.cstorm.is" "noexist.thc" "barcelona.cstorm.is")
  unset res

  # Use size 42 (20 IP + 8 ICMP + 42 Payload == 70)
  iptables -A OUTPUT -o eth0 -p icmp -m length --length 70 -j ACCEPT
  readarray -t res < <(fping -c5 -4 -q -b 42 "${hosts[@]}" 2>&1)
  iptables -D OUTPUT -o eth0 -p icmp -m length --length 70 -j ACCEPT

  # Return if we didnt get any results...
  [[ ${#res[@]} -le 0 ]] && { WARN "No results from any server (PROVIDER=${PROVIDER}). Firewalled?"; return; }

  # If one of the hosts did not resolve then its discarded from
  # the result list. Thus we need to match them all up again
  local n
  local max
  local avg
  local arr
  n=0
  unset arr
  while [[ $n -lt "${#res[@]}" ]]; do
    str="${res[$n]}"
    ((n++))
    loss="${str%\%*}"
    loss="${loss##*/}"
    [[ $loss -gt 20 ]] && continue # more than 1 packet got lost.
    name="${str%% *}"
    max="${str##*/}"
    str="${str%/*}"
    avg="${str##*/}"
    # Arrange so that average is first (for sort -n)
    arr+=("$avg $name")
  done

  # All have packet loss?
  [[ ${#arr[@]} -le 0 ]] && { WARN "Could not ping any server. Firewalled?"; return; }

  # Sort list and store in array
  unset sorted
  readarray -t sorted < <(shuf -e "${arr[@]}" | sort  -n)

  # Need to match up sorted list's hostnames with the original
  # list of hosts (positions)
  n=0
  unset pos_arr
  while [[ $n -lt ${#sorted[@]} && $n -le $pos ]]; do
    str="${sorted[$n]}"
    str="${str##* }"
    ((n++))
    # Find this host in our hosts array
    i=0
    while [[ $i -lt ${#hosts[@]} ]]; do
      host="${hosts[$i]}"
      [[ "$host" == "$str" ]] && { pos_arr+=("$i"); break; }
      ((i++))
    done
  done

  # See if POS is beyond end of array
  [[ $pos -ge ${#pos_arr[@]} ]] && { WARN "Server #${pos} not found. Only ${#pos_arr[@]} available."; return; }

  n=${pos_arr[$pos]}
  AUTO_SERVER="${servers[$n]}"
  h="${hosts[$n]}"
  END_POINT="${h}"
  [[ -n ${ports[$n]} ]] && END_POINT+=":${ports[$n]}"

  # Translate to IP address if it isnt already
  EP_IP=$(hn2ip "${hosts[$n]}")
  WG_EP_PORT="${END_POINT##*\:}"
}


MV_JSON_FILE="/etc/wireguard-mullvad/mullvad.json"
# Set AUTO_SERVER to the server we selected.
mullvad_select()
{
  local search
  local city
  search="$1"

  unset AUTO_SERVER

  # Check if it is a direct match
  AUTO_SERVER=$(jq -r '.countries[].cities[].relays[] | select(.hostname == "'"$search"'") | .hostname' "${MV_JSON_FILE}")
  [[ -n $AUTO_SERVER ]] && return 0

  # First try to see if 'search' matches COUNTRY. Otherwise try matching 'search' with CITY.
  # Pick a random city by country
  city=$(jq -r '.countries[] | select(.name | match("^'"$search"'"; "i")) | .cities[].name'  "${MV_JSON_FILE}" | shuf -n1)
  if [[ -z $city ]]; then
    # No match. Try picking a city by City.
    city=$(jq -r '.countries[].cities[] | select(.name | match("^'"$search"'"; "i")) | .name'  "${MV_JSON_FILE}" | shuf -n1)
  fi

  [[ -n $city ]] && AUTO_SERVER=$(jq -r '.countries[].cities[] | select(.name == "'"${city}"'") | .relays[].hostname'  "${MV_JSON_FILE}" | shuf -n1)
  [[ -n $AUTO_SERVER ]] && return 0

  return 255
}

reconnect_init()
{
  [[ -z $RECONNECT ]] && return

  echo "[$(date -Iseconds)] Reconnecting in ${RECONNECT} seconds..."
  RE_EXPIRE=$(($(date +%s) + RECONNECT))
}

# Return TRUE if it needs a reconnect
need_reconnect()
{
  local n
  [[ -z $RECONNECT ]] && return 255

  [[ $(date +%s) -ge $RE_EXPIRE ]] && return 0
}

wg_finish()
{
  wg-quick down wg0 2>/dev/null
#   iptables -D OUTPUT -o eth0 -p udp -m udp -d "${EP_IP}" --dport "${WG_EP_PORT}" -j ACCEPT
}

wg_up()
{
  local cf
  local id
  local dir
  dir="$1"
  sname="$2"
  id="$3"

  unset WG_EP_PORT
#   unset WG_DNS
  unset END_POINT
  unset EP_IP
  unset PUBLIC_KEY
  unset GEOIP

  if [[ "${sname,,}" == "auto" ]]; then
    auto_select_server
    [[ -z ${AUTO_SERVER} ]] && { WARN "No server found ¯\_(⊙︿⊙)_/¯."; return 255; }
    sname="${AUTO_SERVER}"
  fi

  if [[ "${PROV}" != "nordvpn" ]]; then
    if [[ "${PROV}" == "mullvad" ]]; then
      # Mullvad supports regex. Find sname by regex over city
      mullvad_select "${sname,,}"
      [[ -z ${AUTO_SERVER} ]] && { WARN "No server found ¯\_(⊙︿⊙)_/¯."; return 255; }
      sname="${AUTO_SERVER}"
    fi

    # HERE: Cryptostorm/Mullvad from templates
    cf="${dir}/${sname}.conf"

    [[ ! -f "${cf}" ]] && {
      ERR "Not found: ${cf} ¯\_(⊙︿⊙)_/¯."
      return 255
    }
    [[ -z $END_POINT ]] && {
      str="$(grep ^Endpoint "${cf}")"
      END_POINT="${str##* }"
    }

    [[ -z $PUBLIC_KEY ]] && {
      str="$(grep ^PublicKey "${cf}")"
      PUBLIC_KEY="${str##* }"
    }

    [[ -z $EP_IP ]] && EP_IP="$(hn2ip "${END_POINT%%\:*}")"
    [[ ${END_POINT} == *:* ]] && WG_EP_PORT="${END_POINT##*\:}"

    [[ -z $GEOIP ]] && {
      str=$(grep '# GEOIP=' "${cf}")
      GEOIP="${str:8}"
    }

    # WG_DNS="$(grep ^DNS "${cf}")"
    # WG_DNS="${WG_DNS##* }"
  else
    nordvpn_select "${sname,,}"
    sname="${AUTO_SERVER}(${sname##*=})"
    # NordVPN's DNS servers
    # WG_DNS="103.86.96.100,103.86.99.100"
  fi

  # HERE: NordVPN, Mullvad, CryptoStorm

  # Use default if no DNS supplied in Templates.
#   [[ -z $WG_DNS ]] && WG_DNS="1.1.1.1,8.8.8.8"

  [[ -n $EP_PORT ]] && WG_EP_PORT="${EP_PORT}"
  WG_EP_PORT="${WG_EP_PORT:-51820}"

  [[ -z $END_POINT ]] && { WARN "${sname}: No Endpoint found ¯\_(⊙︿⊙)_/¯."; return 255; }
  [[ -z $PUBLIC_KEY ]] && { WARN "${sname}: No PublicKey found ¯\_(⊙︿⊙)_/¯."; return 255; }
  [[ -z $EP_IP ]] && { WARN "${sname}: EP_IP not set ¯\_(⊙︿⊙)_/¯."; return 255; }

  # Allow WireGuard traffic to the endpoint.
#   iptables -A OUTPUT -o eth0 -p udp -m udp -d "${EP_IP}" --dport "${WG_EP_PORT}" -j ACCEPT

  # Force user supplied DNS (if specified)
#   [[ -n $DNS ]] && WG_DNS="$DNS"

  unset psk_str
  [[ -n $PSK ]] && psk_str="Presharedkey = ${PSK}"$'\n'

    ( umask 077 && { cat >/etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = ${ADDRESS}
PreUp = ${PRE_UP}
PostUp = ${POST_UP}
PreDown = ${PRE_DOWN}
PostDown = ${POST_DOWN}

[Peer]
${psk_str}\
PublicKey = ${PUBLIC_KEY}
Endpoint = ${EP_IP}:${WG_EP_PORT}
AllowedIPs = ${ALLOWED_IPS:-0.0.0.0/0}
PersistentKeepalive = ${PERSISTENT_KEEP_ALIVE:-25}
# GEOIP=${GEOIP}
EOF
    } && sync )

    echo -e "[$(date -Iseconds)] Connecting to #${id}: ${CDM}${sname}${CN} (${EP_IP}:${WG_EP_PORT})..."
    wg-quick up wg0 || { wg_finish; return 255; }

    # HERE: Will only execute after POST_UP has finished.
    # Wait until handshake is complete.
    echo -e "[$(date -Iseconds)] [${CDM}${sname}${CN}] Connected! \(ᵔᵕᵔ)/"
    reconnect_init
    # Monitor connection...
    while :; do
        need_reconnect && break
        sleep 120
        check_vpn "${PROVIDER}" wg0 || { WARN "[${CDM}${sname}${CN}] VPN check failed."; wg_finish; return 255; }
    done

    # HERE: Reconnect time expired => RECONNECT to next server.
    wg_finish
    return 0
}

[[ $(sysctl -n net.ipv4.ip_forward) -ne 1 ]] && WARN "ip_forward= not set"
[[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) -ne 1 ]] && WARN "net.ipv4.conf.all.src_valid_mark= not set"

# Operate on Ramdisk
[[ ! -d /dev/shm/wireguard ]] && mkdir /dev/shm/wireguard

[[ -z $PROVIDER ]] && PROVIDER="CryptoStorm"
PROV="${PROVIDER,,}"

[[ -n $CONFIG ]] && {
  str="$CONFIG"
  [[ -z $SERVER ]] && SERVER="${str%%:::*}"
  str="${str#*:::}"
  [[ -z $PRIVATE_KEY ]] && PRIVATE_KEY="${str%%:::*}"
  str="${str#*:::}"
  [[ -z $PSK ]] && PSK="${str%%:::*}"
  [[ -z $ADDRESS ]] && ADDRESS="${str#*:::}"
}

[[ "${PSK,,}" == "none" ]] && unset PSK
[[ "${ADDRESS,,}" == "none" ]] && unset ADDRESS
[[ -z $SERVER ]] && SERVER="auto"
[[ -z $PRIVATE_KEY ]] && SLOWEXIT 10 "PRIVATE_KEY= not set ¯\_(⊙︿⊙)_/¯."

if [[ "${PROV}" != "nordvpn" ]]; then
  # NordVPN does not need ADDRESS. All others do.
  [[ -z $ADDRESS ]] && SLOWEXIT 10 "ADDRESS is not."
fi

n=0
unset servers
s="${SERVER}"
while :; do
  servers+=("${s%%+*}")
  [[ "${s}" != *"+"* ]] && break
  s="${s#*+}"
done

source /check_vpn.sh

# Pick a random server number to start with.
id=0
# [[ "${servers[0],,}" != "auto" ]] && id=$((RANDOM % ${#servers[@]}))
err_count=0
while :; do
  { wg_up "/etc/wireguard-${PROV}" "${servers[$id]}" "$id" && err_count=0; } || {
    ((err_count++))
    [[ $err_count -ge ${#servers[@]} ]] && SLOWEXIT 30 "All servers have errors...(Total: ${#servers[@]})" #EXIT
    sleep 1
  }

  ((id++))
  id=$((id%${#servers[@]}))
done

sleep 5
exit 255 # NOT REACHED
