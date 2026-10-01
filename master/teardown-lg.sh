#! /bin/bash

# Context: SF-MASTER
#
# Called every time encfsd shuts down an LG.

LID="${1:?}"

# segfaultsh may have called ERREXIT before container was created (and before config.txt was created)
[ ! -f "/dev/shm/sf/run/users/lg-${LID}/config.txt" ] && exit 0

source "/sf/bin/funcs.sh" || exit 255
source "/dev/shm/config-lg.txt" || exit 255 # For SF_ROUTER_PID
source "/dev/shm/sf/run/users/lg-${LID}/config.txt" || exit 255

# Older running guests have no saved identity. Only use their init PID if Docker
# still associates it with the same container instance.
if [[ -z $LG_NETNS ]]; then
	current=$(docker inspect -f '{{.Id}} {{.State.Pid}}' "lg-${LID}") || exit 1
	[[ $current == "${CID:?} ${LG_PID:?}" && $LG_PID -gt 1 ]] || {
		ERR "[${LID}] Guest init is gone and no network namespace identity was saved."
		exit 1
	}
	LG_NETNS=$(docker exec --user 0 sf-host readlink "/proc/${LG_PID}/ns/net") || exit 1
	[[ $(docker inspect -f '{{.Id}} {{.State.Pid}}' "lg-${LID}") == "$current" ]] || exit 1
	# Preserve this identity for retries if cleanup stops init but another member survives.
	printf "LG_NETNS='%s'\n" "$LG_NETNS" >>"/dev/shm/sf/run/users/lg-${LID}/config.txt" || exit 1
fi

# SSH transports can outlive the guest and retain its WG sockets. sf-host has
# host PID visibility and SYS_PTRACE, needed to inspect namespaces across UIDs.
docker exec --user 0 -i sf-host bash -s -- "$LG_NETNS" "$$" <<'EOF'
netns=$1
master_pid=$2
[[ $netns =~ ^net:\[[0-9]+\]$ ]] || exit 1
[[ $netns != "$(readlink /proc/self/ns/net)" && $netns != "$(readlink /proc/1/ns/net)" ]] || exit 1

in_guest_ns() { [[ $(readlink "$1" 2>/dev/null) == "$netns" ]]; }

# Pin the namespace through a surviving member, then check again in case that
# PID exited or was reused between readlink and open. Close the FD on exit.
for path in /proc/[0-9]*/ns/net; do
	in_guest_ns "$path" || continue
	{ exec {netfd}<"$path"; } 2>/dev/null || continue
	in_guest_ns "/proc/self/fd/$netfd" && break
	exec {netfd}<&-
	unset netfd
done
[[ -n $netfd ]] || exit 0

# Use master's iproute2, keeping the namespace pinned until cleanup finishes.
nsenter -t "$master_pid" -m -r -n"/proc/self/fd/$netfd" -- sh -c '
	links=$(ip -o link show group 31337) || exit 1
	[ -z "$links" ] || ip link delete group 31337
' || exit 1

for signal in TERM KILL; do
	for path in /proc/[0-9]*/ns/net; do
		in_guest_ns "$path" || continue
		pid=${path#/proc/}
		pid=${pid%%/*}
		kill -s "$signal" "$pid" 2>/dev/null
	done
	[[ $signal == TERM ]] && sleep 1
done

# Allow pending signals to take effect before deciding whether cleanup needs a retry.
for attempt in {1..10}; do
	remaining=
	for path in /proc/[0-9]*/ns/net; do
		in_guest_ns "$path" && { remaining=1; break; }
	done
	[[ -z $remaining ]] && exit 0
	sleep 0.1
done
exit 1
EOF
[[ $? -eq 0 ]] || { ERR "[${LID}] Network namespace cleanup failed; retaining cleanup state for retry."; exit 1; }

# OpenVPN cleanup
killall "openvpn-${LID}" 2>/dev/null
rm -rf "/tmp/lg-${LID}" 2>/dev/null

nsenter -t "${SF_ROUTER_PID:?}" -n -m sh -c '
. "/dev/shm/net-devs.txt"
. "/sf/run/users/lg-'"${LID}"'/config.txt"
LID="'"${LID}"'"
CHAIN="SYN-${SYN_LIMIT}-${SYN_BURST}-${IDX}"
iptables -D FORWARD -i "${DEV_LG:?}" -s "${C_IP:?}" -j "FW-${LID}"
iptables -F "FW-${LID}"
iptables -X "FW-${LID}" || { iptables -F "FW-${LID}"; sleep 1; iptables -X "FW-${LID}"; }
iptables -nL "$CHAIN" | grep -qm1 "^Chain.*0 references" && {
    iptables -F "$CHAIN"
    iptables -X "$CHAIN"
}
'

exit 0
