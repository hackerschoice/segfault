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

# add [PORT]
xadd()
{
	cp "/var/lib/tor/hidden/service-${1}/hostname" "/config/guest/onion_hostname-${1}"
	chmod 644 "/config/guest/onion_hostname-${1}"
}

sleep_copy()
{
	sleep 5
	xadd 22
	xadd 80
	exit 0
}

# Route all traffic that comes to this instance through TOR.
iptables -t nat -A PREROUTING -p tcp ! -d sf-tor --syn -j REDIRECT --to-ports 9040
# Route to SSHD and NGINX via sf-router
ip route add 172.22.0.22/32 via 172.20.0.2
ip route add 172.20.1.80/32 via 172.20.0.2

chmod 700 /var/lib/tor
chown -R tor /var/lib/tor/hidden || ERREXIT
chmod -R 700 /var/lib/tor/hidden || ERREXIT

# TOR does not have an option to generate keys. Instead wait in the
# background until keys are generated and then copy hostname to
# guest's config dir.
[[ ! -f /var/lib/tor/hidden/service-22/hostname ]] && sleep_copy &

# chmod 644 /var/lib/tor/hidden/service-22/hostname
# chmod 644 /var/lib/tor/hidden/service-80/hostname

if [[ -f /config/host/etc/tor/torrc ]]; then
	exec su -s /bin/ash - tor -c "tor --hush -f /config/host/etc/tor/torrc"
else
	exec su -s /bin/ash - tor -c "tor --hush"
fi
# NOT REACHED
