#! /bin/bash

create_load_seed()
{
	[[ -n $SF_SEED ]] && return
	[[ ! -f "/config/seed/seed.txt" ]] && {
		head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32 >/config/seed/seed.txt || { echo >&2 "Can't create \${SF_BASEDIR}/config/etc/seed/seed.txt"; exit 255; }
	}
	SF_SEED="$(cat /config/seed/seed.txt)"
	[[ -z $SF_SEED ]] && { echo >&2 "Failed to generated SF_SEED="; exit 254; }
}

[[ ! -d /sf/run/gsnc ]] && { echo >&2 "Forgot -v \${SF_SHMDIR:-/dev/shm/sf}/run/gsnc:/sf/run/gsnc?"; sleep 5; exit 253; }
[[ ! -d /config/seed ]] && { echo >&2 "Forgot -v config/etc/seed:/config/seed?"; sleep 5; exit 252; }

create_load_seed

# This is the GS_SECRET to get to SSHD (and gs-netcat in cleartext [-C] could be used).
# It can be cryptographically weak. The security is provided by SSHD. 
GS_SECRET=$(echo -n "GS-${SF_SEED}${SF_FQDN}" | sha512sum | base64 | tr -dc '[:alpha:]' | head -c 12)

[[ ! -f /sf/run/gsnc/access-22.txt ]] && echo "${GS_SECRET}" >/sf/run/gsnc/access-22.txt

exec /gs-netcat -l -d "$1" -p 22 -s "22-${GS_SECRET}"
