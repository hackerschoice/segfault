#! /bin/bash


[[ -z $SF_SEED ]] && { echo >&2 "SF_SEED= not set"; sleep 5; exit 255; }
ip route del default
ip route add default via 172.22.0.254

# This is the GS_SECRET to get to SSHD (and gs-netcat in cleartext [-C] could be used).
# It can be cryptographically weak. The security is provided by SSHD. 
GS_SECRET=$(echo -n "GS-${SF_SEED}${SF_FQDN}" | sha512sum | base64 -w0)
GS_SECRET="${GS_SECRET//[^[:alpha:]]}"
GS_SECRET="${GS_SECRET:0:12}"

echo "${GS_SECRET}" >/config/guest/gsnc-access-22.txt

exec /gs-netcat -l -d "$1" -p 22 -s "22-${GS_SECRET}"
