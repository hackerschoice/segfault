#! /bin/bash

# Context: SF-ROUTER (network + mount)
#
# Executed for each newly created LG.
# Set User's TCP SYN limit and others
# [YOUR_IP] [Container IP] [SYN_LIMIT 1/sec] [SYN_BURST]

LID="${1:?}"

set -e  # Exit immediately on error
source "/dev/shm/net-devs.txt"
source "/sf/run/users/lg-${LID}/limits.txt"
source "/sf/run/users/lg-${LID}/config.txt"

set +e # DO NOT Exit immediately on error.

fn="/config/db/token/netns-${SF_USER_FW}.sh"
FORWARD_USER="FW-${LID:?}"

# Set a fixed MAC address on ROUTER for each LG
arp -s "${C_IP:?}" "${LG_MAC:?}"

# Flush if exist or create new.
iptables -F "${FORWARD_USER}" 2>/dev/null || iptables -N "${FORWARD_USER}"
iptables -C FORWARD -i "${DEV_LG:?}" -s "${C_IP}" -j "${FORWARD_USER}" &>/dev/null || iptables -I FORWARD 1 -i "${DEV_LG}" -s "${C_IP}" -j "${FORWARD_USER}"
[ -n "$SF_USER_FW" ] && {
    [ ! -f "$fn" ] && { echo >&2 "File ${fn} not found"; exit 255; }
    set -e
    source "$fn"
    set +e
}

# Create our own 'hashmap' so that SYN is limited by user's source IP (e.g. user can spawn two
# servers and both servers have a total limit of SYN_LIMIT)
# - User may have 2 servers from same source ip but with different SYN-limits (token + non-token server).
#   => Both servers shall go into separate sync-limit-Chains.
# IDX=$((0x${YOUR_IP_HASH} % 1024))
# [[ $IDX -lt 0 ]] && IDX=$((IDX * -1))

[[ -n $SYN_LIMIT ]] && [[ "$SYN_LIMIT" -gt 0 ]] && {

    CHAIN="SYN-${SYN_LIMIT}-${SYN_BURST}-${IDX}"
    IPT_FN="/dev/shm/ipt-syn-chain-${C_IP}.saved"

    # Might already exist (by same YOUR_IP or hash collision)
    iptables --new-chain "${CHAIN}" 2>/dev/null && {
        # CREATE chain:
        # - Same chain can be shared by multiple LIDs [if all use same YOUR_IP])
        iptables -A "${CHAIN}" -m limit --limit "${SYN_LIMIT}/sec" --limit-burst "${SYN_BURST}" -j RETURN
        iptables -A "${CHAIN}" -j DROP
    }

    set -e
    iptables -I "${FORWARD_USER}" 1 -p tcp --syn -j "${CHAIN}"

    # Save chain name for 'curl sf/ipt'
    echo "${CHAIN}" >"${IPT_FN}"
    set +e
}

# { [[ -n $USER_DL_RATE ]] || [[ -n $USER_UL_RATE ]]; } && {
#     D="${C_IP##*\.}"
#     str="${C_IP%\.*}"
#     C="${str##*\.}"
#     IPIDX=$((C * 256 + D))
#     unset C D str

#     # FIXME: nft to throttle upload speed after 8gb transfer?
# }

exit 0
