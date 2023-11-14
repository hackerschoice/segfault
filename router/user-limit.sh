#! /bin/bash

# Executed on router
# Set User's TCP SYN limit and others
# [YOUR_IP] [Container IP] [SYN_LIMIT 1/sec] [SYN_BURST]

LID="$1"
YOUR_IP_HASH="$2"
YOUR_IP="$3"
C_IP="$4"
SYN_LIMIT="$5"
SYN_BURST="$6"

set -e  # Exit immediately on error
source "/dev/shm/net-devs.txt"
source "/sf/run/users/lg-${LID}/limits.txt"

fn="/config/db/token/netns-${SF_USER_FW}.sh"
FORWARD_USER="FW-${C_IP:?}"
set +e
iptables -F "${FORWARD_USER}" 2>/dev/null || iptables -N "${FORWARD_USER}"
[[ -n $SF_USER_FW ]] && [[ -f "$fn" ]] && {
    iptables -C FORWARD -i "${DEV_LG:?}" -s "${C_IP}" -j "${FORWARD_USER}" &>/dev/null || iptables -I FORWARD 1 -i "${DEV_LG}" -s "${C_IP}" -j "${FORWARD_USER}"
    set -e
    source "$fn"
    set +e
}


# Create our own 'hashmap' so that SYN is limited by user's source IP (e.g. user can spawn two
# servers and both servers have a total limit of SYN_LIMIT)
IDX=$((0x${YOUR_IP_HASH} % 1024))
[[ $IDX -lt 0 ]] && IDX=$((IDX * -1))

[[ -n $SYN_LIMIT ]] && {
    CHAIN="SYN-${SYN_LIMIT}-${SYN_BURST}-${IDX}"
    IPT_FN="/dev/shm/ipt-syn-chain-${C_IP}.saved"

    # Might already exist (by same YOUR_IP or hash collision)
    iptables --new-chain "${CHAIN}" 2>/dev/null && {
        # Add limits to chain (same chain can be shared by multiple LIDs [if all use same YOUR_IP])
        iptables -A "${CHAIN}" -m limit --limit "${SYN_LIMIT}/sec" --limit-burst "${SYN_BURST}" -j RETURN
        iptables -A "${CHAIN}" -j DROP
    }

    set -e
    # Delete stale iptables-FORWARD rule for this C_IP (if it exist then it would go to wrong chain)
    [[ -e "${IPT_FN}" ]] && iptables -D FORWARD -i "${DEV_LG}" -s "${C_IP}" -p tcp --syn -j "$(<"$IPT_FN")"
    # New chain must be hit before our global SYN-limit chain => Use '-I FORWARD 1'
    iptables -I FORWARD 1 -i "${DEV_LG}" -s "${C_IP}" -p tcp --syn -j "${CHAIN}"

    # Save chain name
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
