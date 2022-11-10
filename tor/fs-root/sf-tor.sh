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

# Tor has no easy way to generate keys in a script and then derive the onion address
# from the public key. This is a nightmare.
# (We need the onion address before we start TOR....)
genkey_hidden()
{
	local port
	local dir
	port="$1"
	dir="/var/lib/tor/hidden/service-$1"

	[[ ! -d "${dir}/authorized_clients" ]] && mkdir -p "${dir}/authorized_clients"
	[[ ! -f "${dir}/hs_ed25519_secret_key" ]] && {
		mkdir /tmp/tor
		chown tor /tmp/tor
		chown tor "${dir}"
		(sleep 1; echo -en "\r\r") | su -s /bin/ash - tor -c 'script -q -c "tor --keygen --DataDirectory /tmp/tor" /dev/null' >/dev/null
		cp /tmp/tor/keys/ed25519_master_id_secret_key "${dir}/hs_ed25519_secret_key"
		cp /tmp/tor/keys/ed25519_master_id_public_key "${dir}/hs_ed25519_public_key"
		rm -rf /tmp/tor
		rm -f "${dir}/hostname"
	}

	[[ ! -f "${dir}/hostname" ]] && {
		# Create ./hostname from public key
		pub=$(tail --bytes 32 <"${dir}/hs_ed25519_public_key")
		chk=$((echo -n ".onion checksum${pub}"; echo -en "\003") | openssl sha3-256 -binary | head --bytes 2)
		s=$((echo -n "${pub}${chk}"; echo -en "\003") | base32)
		echo "${s,,}.onion" >"${dir}/hostname"
		echo "Port ${port}: ${s,,}.onion"
	}

	# Always fix permission (and also when files already existed)
	find "${dir}" -type d -exec chmod 700 {} \; || ERREXIT
	find "${dir}" -type f -exec chmod 600 {} \; || ERREXIT
}

# Route all traffic that comes to this instance through TOR.
iptables -t nat -A PREROUTING -p tcp ! -d sf-tor --syn -j REDIRECT --to-ports 9040
# Route to SSHD and NGINX via sf-router
ip route add 172.22.0.22/32 via 172.20.0.2
ip route add 172.20.1.80/32 via 172.20.0.2

umask 0077
genkey_hidden 22
genkey_hidden 80
umask 0022
xadd 22
xadd 80

chmod 700 /var/lib/tor
chown -R tor /var/lib/tor/hidden || ERREXIT

if [[ -f /config/host/etc/tor/torrc ]]; then
	exec su -s /bin/ash - tor -c "tor --hush -f /config/host/etc/tor/torrc"
else
	exec su -s /bin/ash - tor -c "tor --hush"
fi
# NOT REACHED
