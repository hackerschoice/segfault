#! /bin/ash

CR="\033[1;31m" # red
CG="\033[1;32m" # green
CN="\033[0m"    # none

ERREXIT()
{
	local code
	code="$1"
	[[ $? -ne 0 ]] && code="$?"
	[[ -z $code ]] && code=99

	shift 1
	[[ -n "$1" ]] && echo -e >&2 "${CR}ERROR:${CN} $*"

	exit "$code"
}

[[ -d /var/lib/tor/hidden_service ]] || ERREXIT 254 "Not found: /var/lib/tor/hidden_services. Forgot -v option?"
chown tor /var/lib/tor/hidden_service || ERREXIT
chmod 700 /var/lib/tor/hidden_service || ERREXIT
echo -e "ONION: ${CG}http://$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null)${CN}"
[[ -f /config/torrc ]] && { exec su -s /bin/ash - tor -c "tor -f /config/torrc"; true; } || exec su -s /bin/ash - tor -c "tor"
# NOT REACHED
