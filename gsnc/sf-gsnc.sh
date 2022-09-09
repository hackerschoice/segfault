#! /bin/bash

create_load_seed()
{
	[[ -n $SF_SEED ]] && return
	[[ ! -f "/config/etc/seed/seed.txt" ]] && {
		head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32 >/config/etc/seed/seed.txt || { echo >&2 "Can't create \${SF_BASEDIR}/config/etc/seed/seed.txt"; exit 255; }
	}
	SF_SEED="$(cat /config/etc/seed/seed.txt)"
	[[ -z $SF_SEED ]] && { echo >&2 "Failed to generated SF_SEED="; exit 254; }
}

[[ ! -d /config/guest ]] && { echo >&2 "Forgot -v \${SF_SHMDIR:-/dev/shm/sf}/config-for-guest:/config/guest?"; sleep 5; exit 253; }
[[ ! -d /config/etc/seed ]] && { echo >&2 "Forgot -v config/etc/seed:/config/etc/seed?"; sleep 5; exit 252; }

create_load_seed

ip route del default
ip route add default via 172.22.0.254

# This is the GS_SECRET to get to SSHD (and gs-netcat in cleartext [-C] could be used).
# It can be cryptographically weak. The security is provided by SSHD. 
GS_SECRET=$(echo -n "GS-${SF_SEED}${SF_FQDN}" | sha512sum | base64 | tr -dc '[:alpha:]' | head -c 12)

[[ ! -f /config/guest/gsnc-access-22.txt ]] && echo "${GS_SECRET}" >/config/guest/gsnc-access-22.txt

exec /gs-netcat -l -d "$1" -p 22 -s "22-${GS_SECRET}"
