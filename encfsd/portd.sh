#! /bin/bash

# SECURITY: This container has access to docker-socket.

# Reverse Port Manager. Receives requests from segfaultsh to assign a reverse port forward.
# Uses BLPOP as a blocking mutex so that only 1 segfaultsh
# can request a port at a time (until the request has been completed).


##### BEGIN TESTING #####
false && {
# Requests (for testing)
SF_REDIS_SERVER=127.0.0.1 SF_DEBUG=1 ./portd.sh

# Cryptostorm add port to available port list:
docker exec -it sf-cryptostorm curl 10.31.33.7/fwd
docker exec segfault_sf-redis_1 bash -c 'echo -e "\
SADD portd:providers CryptoStorm\n\
SADD portd:ports \"CryptoStorm 37.120.217.76:31337\"" | \
REDISCLI_AUTH="${SF_REDIS_AUTH}" redis-cli --raw'

# Test log in
ssh -p2222 -o "SetEnv SF_DEBUG=1" root@127.1

# Redis commands to test mutex
DEL portd:response-0bcdefghi9
RPUSH portd:blcmd "getport 0bcdefghi9"
BLPOP portd:response-0bcdefghi9 5
}
##### END TESTING ###

# High/Low watermarks for pool of ports
# Refill pool to WM_HIGH if it ever drops below WM_LOW
WM_LOW=2
WM_HIGH=5

# BASEDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
source "/sf/bin/funcs.sh"

SF_REDIS_SERVER="${SF_REDIS_SERVER:-sf-redis}"

REDCMD+=("redis-cli" "--raw" "-h" "${SF_REDIS_SERVER}")

redr()
{
	local res
	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res ]] && return 200
	echo "$res"
	return 0
}

red()
{
	local res

	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res ]] && return 200
	echo "$res"
	return 0
}

# Redis Last Line
redll()
{
	local res

	res=$("${REDCMD[@]}" "$@") || return 255
	res="${res##*$'\n'}"
	[[ -z $res ]] && return 200
	echo "$res"
	return 0
}

# [LID] [PROVIDER] [IP] [PORT]
config_port()
{
	local p
	local c_ip
	local r_port
	local r_ip
	local lid
	local provider
	lid="$1"
	provider="$2"
	r_ip="$3"
	r_port="$4"

	DEBUGF "Setting routing for ip=${r_ip} port=${r_port}"

	# Find out IP address.
	c_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "lg-${lid}")
	[[ -z $c_ip ]] && { ERR "Could not get container's IP address."; return 255; }

	DEBUGF "Container IP=$c_ip"
	# Set up routing in Provider Context
	docker exec "sf-${provider,,}" /sf/bin/rportfw.sh fwport "${r_ip}" "${r_port}" "${c_ip}" "${lid}"
	ret=$?

	return $ret
}

# "[LID]" "[PROVIDER] [IP:PORT]"
got_port()
{
	local provider
	local r_port
	local r_ip
	local str
	local selfdir
	local lid
	lid="$1"
	provider="${2%% *}"
	str="${2##* }"
	r_ip="${str%%:*}"
	r_port="${str##*:}"
	selfdir="/config/self-for-guest/lg-${lid}"

	# Update User's /config/self/ files
	[[ ! -d "${selfdir}" ]] && mkdir "${selfdir}"
	echo "${r_ip}" >"${selfdir}/reverse_ip"
	echo "${r_port}" >"${selfdir}/reverse_port"

	# FIXME: We could do this asyncronous:
	# 1. have a separate sub shell running for config_port
	# 2. Send command to config_port (fire & forget)
	config_port "${lid}" "${provider}" "$r_ip" "$r_port" || {
		rm -f "${selfdir}/reverse_ip" "${selfdir}/reverse_port"
		return 255
	}

	# 0. Inform (rpush) segfaultsh
	# 1. Record every "[PROVIDER] [PORT]" by lid. Needed when LID exits.
	# 2. Record every "[LID]      [PORT]" by provider. Needed when VPN goes down.
	echo -e "MULTI\n\
RPUSH  portd:response-${lid} \"${r_ip}:${r_port}\"\n\
EXPIRE portd:response-${lid} 10\n\
EXEC\n\
SADD portd:assigned-${lid} \"${provider} ${r_ip}:${r_port}\"\n\
SADD portd:assigned-${provider} \"${lid} ${r_ip}:${r_port}\"" | "${REDCMD[@]}" >/dev/null
}

# Process command 'getport'. This request is send by segfaultsh to Redis
# to request a reverse port forward. Segfaultsh is waiting in mutix until response.
# This script replies with 'portd:response-${lid} $ip:$port'
#
# [LID]
cmd_getport()
{
	local lid
	local res
	local provider
	local port
	local err
	lid="$1"

	# Get a Port
	# [PROVIDER] [PORT]
	i=0
	unset err
	while :; do
		res=$(red SPOP portd:ports) && break
		# Dont wait unless there is a provider serving us..
		# [[ ! "$(red SCARD portd:providers)" -gt 0 ]] && { err=1; break; } # ALWAYS WAIT. Provider might be back soon.
		# Check if we already times out before and since then
		# never got a port...
		[[ -n $IS_NO_PORT_AFTER_WAITING ]] && { err=1; break; }
		[[ "$i" -ge 10 ]] && { IS_NO_PORT_AFTER_WAITING=1; err=1; break; }
		((i++))
		sleep 1
	done

	[[ ! -z $err ]] && {
		# HERE: error encountered.
		echo -e "RPUSH portd:response-${lid} 0:0\nEXPIRE portd:response-${lid} 10" | "${REDCMD[@]}" >/dev/null
		return		
	}

	# Inform protd that we took a port. This will eventually trigger
	# to refill stock with more ports.
	redr RPUSH portd:cmd fillstock >/dev/null
	unset IS_NO_PORT_AFTER_WAITING

	got_port "${lid}" "$res" || {
		DEBUGF "Provider did not respond in time."
		# echo -e "SADD portd:list \"${res}\"" | "${REDCMD[@]}" >/dev/null # ASSUME BAD PORT. DO NOT ADD BACK TO LIST.
		echo -e "RPUSH portd:response-${lid} 0:0\nEXPIRE portd:response-${lid} 10" | "${REDCMD[@]}" >/dev/null
		return
	}

}

# Calld from cmd_remport
# Exec in VPN context to deletion of ports.
#
# [PROVIDER] [LID] [<IPPORT> ...]
remport_provider()
{
	local lid
	local provider
	lid="$1"
	provider="$2"

	shift 2
	[[ ${#@} -lt 1 ]] && return

	# DEBUGF "PARAM-${#@} $*"

	# FIXME: Shall we rather queue the ports for deletion and delete them in
	# bulk when we drop below WM_LOW?
	# Otherwise curl is called every time an instance exits: An observer
	# monitoring the VPN Provider _and_ the SF could correlate reverse port
	# with user's IP.
	# DELIPPORTS+=($@)
	docker exec "sf-${provider,,}" /sf/bin/rportfw.sh delipports "$@"

	# Delete from assgned-$provider list the specifuc IPPORT
	local ipport
	local members
	for ipport in "$@"; do
		members+=("${lid} ${ipport}")
	done
	redr SREM "portd:assigned-${provider}" "${members[@]}" >/dev/null
}

# Remove Ports from LID. Typically called when instance is terminated.
# We never add ports back to the pool. This means that the same port
# is less likely to be reused.
#
# The downside is that this causes a CURL request to the VPN provider
# every time a container exits.
#
# [LID]
cmd_remport()
{
	local lid
	lid="$1"
	local c_ipports
	local n_ipports
	local m_ipports
	local provider

	DEBUGF "CMD_REMPORT lid=$lid"

	# Remove routing
	# -> Dont need to. There is no harm leaving it.

	# Iterate through all ports assigned to this LID (normally just 1)
	while :; do
		res=$(red SPOP "portd:assigned-${lid}") || break
		# [PROVIDER] [PORT]
		provider="${res%% *}"
		ipport="${res##* }"
		[[ -z $ipport ]] && break

		if [[ "${provider,,}" == "cryptostorm" ]]; then
			c_ipports+=($ipport)
		elif [[ "${provider,,}" == "nordvpn" ]]; then
			n_ipports+=($ipport)
		elif [[ "${provider,,}" == "mullvad" ]]; then
			m_ipports+=($ipport)
		else
			continue
		fi
	done

	# Delete ports for each provider
	remport_provider "${lid}" "CryptoStorm" "${c_ipports[@]}"
	remport_provider "${lid}" "NordVPN" "${n_ipports[@]}"
	remport_provider "${lid}" "Mullvad" "${m_ipports[@]}"
}

# VPN provider goes UP.
#
# [PROVIDER]
cmd_vpnup()
{
	local provider
	provider="$1"

	DEBUGF "VPN UP ${provider}"

	[[ "${provider,,}" != "cryptostorm" ]] && return
	redr SADD portd:providers "${provider}" >/dev/null
}

# VPN provider went DOWN.
# [PROVIDER]
cmd_vpndown()
{
	local provider
	local res
	local lid
	local ipport
	# local value
	local files
	provider="$1"

	DEBUGF "VPN DOWN ${provider}"
	redr SREM portd:providers "${provider}" >/dev/null

	# Update all containers that used this provider.
	while :; do
		res=$(red SPOP "portd:assigned-${provider}") || break
		# [LID] [PORT]
		lid="${res%% *}"
		ipport="${res##* }"
		[[ -z $ipport ]] && break

		files+=("/config/self-for-guest/lg-${lid}/reverse_ip")
		files+=("/config/self-for-guest/lg-${lid}/reverse_port")

		# Normally that's 1 member per lg but the lg may have multple
		# port forwards assigned to it.
		# Remove Lid's key/value for this port forward.
		red SREM "portd:assigned-${lid}" "${provider} ${ipport}" >/dev/null
		value+=("${provider} ${ipport}")
	done


	# Remove from portd:ports
	red SREM "portd:ports" "${value[@]}" >/dev/null

	# Delete container files
	rm -f "${files[@]}" &>/dev/null

	# Remove ports from assigned list
	red DEL "portd:assigned-${provider}" >/dev/null
}



# Called when a port was taken from the pool by cmd_getport().
# cmd_getport() is running in a different thread.
cmd_fillstock()
{
	local in_stock
	local ifs_old
	local IFS
	IFS=$'\n'

	in_stock=$(red SCARD portd:ports)

	# Check if we are below our water mark and if so then request more  ports.
	[[ $in_stock -ge "$WM_LOW" ]] && return

	# Get more ports from providers until above high water mark
	local arr
	arr=($(redr SMEMBERS "portd:providers")) || return

	local members
	local good
	local ret
	local req_num
	local max_needed
	while [[ $in_stock -lt $WM_HIGH ]]; do
		unset good
		max_needed=$((WM_HIGH - in_stock))

		req_num=$(( $max_needed / ${#arr[@]} + 1))
		[[ $req_num -gt $max_needed ]] && req_num="$max_needed"
		for provider in "${arr[@]}"; do
			members=($(docker exec "sf-${provider,,}" /sf/bin/rportfw.sh moreports "${req_num}"))
			ret=$?
			# Fatal error. Never try this provider again.
			[[ $ret -eq 255 ]] && redr SREM portd:providers "${provider}"
			# Temporary error.
			[[ $ret -ne 0 ]] && continue

			# If we got what we requested then the provider is GOOD
			# and we can request ports again.
			[[ ${#members[@]} -ge $req_num ]] && good+=("${provider}")

			redr SADD portd:ports "${members[@]}" >/dev/null
			((in_stock+=${#members[@]}))
		done

		# Stop if there is no more good provider
		[[ ${#good[@]} -le 0 ]] && break
		arr=("${good[@]}")
	done

	DEBUGF "Port Stock Level: $in_stock."
}

# Blocking commands such as from segfaultsh. Every request will be acknowledged.
redis_loop_forever_bl()
{
	while :; do
		res=$(redll BLPOP portd:blcmd 0) || { sleep 1; continue; }
		cmd="${res%% *}"
		# DEBUGF "blcmd='$cmd'"

		[[ "$cmd" == "getport" ]] && { cmd_getport "${res##* }"; continue; }
	done 
}

# This is executed asynchronous to forever_bl()
redis_loop_forever()
{
	local fillstock_last_sec=0

	# Non-Blocking commands
	while :; do
		res=$(redll BLPOP portd:cmd 10)
		[[ $? -eq 255 ]] && { sleep 1; continue; }
		# Timeout or $res is set
		cmd="${res%% *}"
		# DEBUGF "cmd='$cmd'"

		NOW=$(date +%s)

		# Commands are executed in order. It might happen that we get VPNUP -> VPNDOWN -> VPNUP
		if [[ "$cmd" == "remport" ]]; then
			cmd_remport "${res##* }"
		elif [[ "$cmd" == "vpnup" ]]; then
			cmd_vpnup "${res##* }"
			fillstock_last_sec=0  # trigger a call to cmd_fillstock
		elif [[ "$cmd" == "vpndown" ]]; then
			cmd_vpndown "${res##* }"
		elif [[ "$cmd" == "fillstock" ]]; then
			cmd_fillstock
			fillstock_last_sec="${NOW}"
		fi

		# Check the fill stock every 60-70 seconds
		[[ $((fillstock_last_sec + 60)) -lt $NOW ]] && { fillstock_last_sec="$NOW"; cmd_fillstock; }		
	done 
}


_trap() { :; }
# Install an empty signal handler so that 'wait()' (below) returns
trap _trap SIGTERM
trap _trap SIGINT

[[ ! -S /var/run/docker.sock ]] && ERREXIT 255 "Not found: /var/run/docker.sock"

export REDISCLI_AUTH="${SF_REDIS_AUTH}"

redis_loop_forever_bl &
BL_CPID=$!
redis_loop_forever &
CPID=$!
wait $BL_CPID # SIGTERM will wake us
# HERE: >128 means killed by a signal.
code=$?
kill $CPID $BL_CPIDD 2>/dev/null
exit "${code}"


