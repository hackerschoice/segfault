#! /bin/bash

CR="\e[1;31m" # red
# CG="\e[1;32m" # green
CN="\e[0m"    # none

ERREXIT()
{
	local code
	code="$1"
	# shellcheck disable=SC2181 #(style): Check exit code directly with e.g
	[[ $? -ne 0 ]] && code="$?"
	[[ -z $code ]] && code=99

	shift 1
	[[ -n "$1" ]] && echo -e >&2 "${CR}ERROR:${CN} $*"

	exit "$code"
}

# Route all traffic that comes to this instance through TOR.
iptables -t nat -A PREROUTING -p tcp --syn -j REDIRECT --to-ports 9040

[[ -d /var/lib/tor/hidden ]] || ERREXIT 254 "Not found: /var/lib/tor/hidden. Forgot -v option?"

chown -R tor /var/lib/tor/hidden || ERREXIT
chmod -R 700 /var/lib/tor/hidden || ERREXIT
chmod 644 /var/lib/tor/hidden/service-22/hostname
chmod 644 /var/lib/tor/hidden/service-80/hostname
# echo -e "ONION: ${CG}http://$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null)${CN}"
if [[ -f /config/tor/torrc ]]; then
	exec su -s /bin/ash - tor -c "tor -f /config/tor/torrc"
else
	exec su -s /bin/ash - tor -c "tor"
fi
# NOT REACHED
