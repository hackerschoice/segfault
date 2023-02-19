#! /bin/bash

# Set User's TCP SYN limit and others
# [YOUR_IP] [Container IP] [LIMIT 1/sec] [BURST]

YOUR_IP="$1"
C_IP="$2"
LIMIT="$3"
BURST="$4"

# Create our own 'hashmap' so that SYN is limited by user's source IP (e.g. user can spawn two
# servers and both servers have a total limit of LIMIT)
str=$(echo -n "$YOUR_IP" | sha512sum)
IDX=$((0x${str:0:16} % 256))
[[ $IDX -lt 0 ]] && IDX=$((IDX * -1))

CHAIN="SYN-${LIMIT}-${BURST}-${IDX}"
IPT_FN="/dev/shm/ipt-syn-chain-${C_IP}.saved"
# CHAIN="SYN-LIMIT-${C_IP}"
source /dev/shm/net-devs.txt || exit

# Flush if exist. Create otherwise.
iptables -F "${CHAIN}" || {
    # HERE: Chain does not exist.
    iptables --new-chain "${CHAIN}" || exit
}
set -e
# Check if iptables-FORWARD rule for this C_IP already exists and delete it if it does.

[[ -e "${IPT_FN}" ]] && iptables -D FORWARD -i "${DEV_LG}" -s "${C_IP}" -p tcp --syn -j "$(<"$IPT_FN")"
iptables -I FORWARD 1 -i "${DEV_LG}" -s "${C_IP}" -p tcp --syn -j "${CHAIN}" || exit
# Save chain name
echo "${CHAIN}" >"${IPT_FN}"
iptables -A "${CHAIN}" -m limit --limit "${LIMIT}/sec" --limit-burst "${BURST}" -j RETURN
iptables -A "${CHAIN}" -j DROP

set +e
