#! /bin/bash

# CONTEXT: VPN context. Call from portd.sh (sf-portd context)

# Executed by portd.sh inside VPN context.
# Set the FW and routing for reverse ip port forwarding.

source "/sf/bin/funcs.sh"
source "/sf/bin/funcs_redis.sh"

ipbydev()
{
	local _ip
	_ip="$(ip addr show "${1}")"
	_ip="${_ip#*inet }"
	_ip="${_ip%%/*}"
	[[ -n $_ip ]] && { echo "$_ip"; return; }
	echo -e >&2 "IP for dev '${1}' not found. Using ${2:-ERROR}"
	echo "${2:?}"
}

# Remove a single iptable line and associated forward rules.
# ["output of iptables -L -n"] as a single string.
fw_del_single()
{
	local line
	local c_ip
	local port
	line="$1"

	a=($line)
	c_ip="${a[7]##*:}"
	port="${a[6]##*:}"
	iptables -t nat -D PREROUTING -i wg0 -p "${a[5]}" -d "${a[4]}" --dport "${port}" -j DNAT --to-destination "${c_ip}"
	iptables -D FORWARD -i wg0 -p "${a[5]}" -d "${c_ip}" --dport "${port}" -j ACCEPT
}

# Delete all Port Forwarding rules matching this R-PORT
# [R-PORT]
fw_del()
{
	local port
	port="$1"

	local line
	iptables -t nat -L PREROUTING -n | grep -F "dpt:${port}" | while read line; do
		fw_del_single "$line"
	done

	return
}

# [IP] - String matches such as "10.11." or "10.11.0.8"] are permitted.
fw_del_byip()
{
	local match
	match="$1"

	iptables -t nat -L PREROUTING -n | while read x; do
		[[ "${a[4]}" != "${match}"* ]] && continue
		del_single "$x"
	done

	return
}

# Remove the Port Forward & FW rules for a list of ports.
# Called from portd.sh when a container exited (by sf-destructor)
#
# [<IPPORT>...]
cmd_delipports()
{
	local ipport
	local r_port
	local res
	local err

	[[ "${PROVIDER,,}" != "cryptostorm" ]] && return

	DEBUGF "cmd_delipports ${PROVIDER} '${*}'"

	err=1
	for ipport in "$@"; do
		r_port="${ipport##*:}"

		res=$(curl -fsSL --retry 3 --max-time 10 http://10.31.33.7/fwd "-ddelfwd=${r_port}" 2>/dev/null) && {
			# [[ $res == *"has been removed"* ]] && unset err
			[[ "$res" != *":${r_port}" ]] && unset err
		}

		[[ -n $err ]] && {
			ERR "${PROVIDER} Failed to remove Port Forward (${ipport})"
			# 2024-09-22, PRIVACY LEAK: CS changed api. It now returns ALL ports but no error.
			# echo "------------------------"
			# echo "${res:0:2048}"
			# echo "------------------------"
		}

		fw_del "${r_port}"
	done
}

# Add firewall/routing information for this port.
#
# [R-IP] [PORT] [CONTAINER-IP] [LID]
cmd_fwport()
{
	local port
	local r_ip
	local c_ip
	local wg_ip
	local lid
	r_ip="$1"
	port="$2"
	c_ip="$3"
	lid="$4"

	[[ -z $c_ip || -z $port ]] && { echo "Bad IP:PORT. ip='${c_ip}' port='$port'"; return 255; }
	fw_del "${port}"

	wg_ip=$(ipbydev wg0 "")
	[[ -z $wg_ip ]] && { echo "Could not retrieve my own wg0 address."; return 255; }

	for proto in tcp udp; do
		iptables -t nat -A PREROUTING -i wg0 -p ${proto} -d "${wg_ip}" --dport "${port}" -j DNAT --to-destination "${c_ip}" || break
		iptables -A FORWARD -i wg0 -p ${proto} -d "${c_ip}" --dport "${port}" -j ACCEPT || break
	done
	[[ $? -ne 0 ]] && { echo "iptables failed with $?."; return 255; }

	LOG "${lid}" "${CW}Forwarding${CN} ${r_ip}:${port} -> ${c_ip}:${CDY}${port}${CN}"
	return 0
}

# Delete stale ports
# This can happen if there was a timeout to reach the VPN provider. 
# Check through all ports and compare to assigned ports in ReDis
# Testing: delstale_cs "$(curl -fsSL --retry 3 --max-time 10 http://10.31.33.7/fwd)"
# [res] [port] 
#   +      +---- The last port that got added (and not yet added to portd:ports and thus must be ignored)
#   +----------- The result from curl -dport=asdf output
delstale_cs()
{
	local res
	local IFS_old
	local arr
	local rarr
	local r
	local str
	local skip_port
	res="$1"
	skip_port="$2"
	IFS_old="$IFS"

	IFS=$'\n'

	# Assigned to containers
	rarr=($(redr SMEMBERS "portd:assigned-CryptoStorm"))
	for str in "${rarr[@]}"; do
		r+=("${str##* }")
	done

	# Assigned in pool of available ports
	rarr=($(redr SMEMBERS "portd:ports"))
	for str in "${rarr[@]}"; do
		[[ "${str%% *}" != "CryptoStorm" ]] && continue
		r+=("${str##* }")
	done

	# Check if CS's return of forwarded port are all
	# still in our list "r" and delete from CS if they are not.
	arr=($res)
	for str in "${arr[@]}"; do
		[[ "$str" != *" ->"* ]] && continue
		ipport="${str%% *}"
		[[ ${r[*]} == *"$ipport"* ]] && continue
		port=${ipport##*:}
		[[ "$port" == "$skip_port" ]] && continue
		WARN "${PROVIDER}: Removing STALE ${ipport}"
		[[ "$port" =~ [^0-9] ]] && continue
		curl -fsSL --max-time 5 http://10.31.33.7/fwd -ddelfwd="${port}" >/dev/null
	done

	IFS="$IFS_old"
}

# Try to request [NUMBER] more ports from the provider.
# Return ="[PROVIDER] ip:ports"= (with quotes) to STDOUT and 0 if
# any port was successfully requested.
#
# Return 255 if this provider should never be tried again.
# Return 0 on success.
#
# [NUMBER]
cmd_moreports()
{
	local members
	local members_num
	local req_num
	local err
	local cur
	err=200
	req_num="$1"


	[[ "${PROVIDER,,}" != "cryptostorm" ]] && return 255

	local i
	i=0
	members_num=0
	# Try 5x the number requested in case we accidentally request a port
	# that was already requested (by us or somebody else).
	cur="$(curl -fsSL --retry 3 --max-time 10 http://10.31.33.7/fwd)" || { sleep 1; return "$err"; }
	while [[ $i -lt $((req_num * 5)) ]]; do
		port=$((30000 + RANDOM % 35534))
		[[ "$cur" == *":${port}"* ]] && continue # Port colission.

		res=$(curl -fsSL --retry 3 --max-time 10 http://10.31.33.7/fwd -dport="$port") || break
		# Check and delete any stale ports
		[[ $i -eq 0 ]] && delstale_cs "$res" "$port" >/dev/null
		((i++))
		# You already have 100 forwards. The max is 100. Please delete some of the existing ones first.
		[[ "$res" == *"You already have "* ]] && { ERR "${PROVIDER} Out of ports!!!"; err=255; break; }        # Max Port Forward reached.
		# 2024-09-22, CS changed api. 
		#[[ "$res" != *"is now forwarding"* ]] && { WARN "${PROVIDER} Failed to get port=${port}."; continue; } # Failed. Try again.

		res="${res%%:${port}*}"
		ip="${res##*$'\n'}"

		[[ "$ip" =~ [^0-9.] ]] && break
		members+="${PROVIDER} ${ip}:${port}"$'\n'
		((members_num++))

		[[ $members_num -ge $req_num ]] && break
	done

	# Could be a temporary failure of curl (200) or fatal (255, out of ports)
	[[ $members_num -le 0 ]] && return "$err"

	echo "${members[*]}"
	return 0
}

cmd="$1"
shift 1

[[ "$cmd" == fwport ]] && { cmd_fwport "$@"; exit; }
[[ "$cmd" == moreports ]] && { cmd_moreports "$@"; exit; }
[[ "$cmd" == delipports ]] && { cmd_delipports "$@"; exit; }     # [<IPPORT> ...]
[[ "$cmd" == fw_delall ]] && { fw_del_byip "10.11."; exit; }
