
# BUG-ARP-CACHE, _must_ use IP address
[[ -z $SF_REDIS_IP ]] && { echo >&2 "SF_REDIS_IP= not set"; return 255; }
# SF_REDIS_SERVER="${SF_REDIS_SERVER:-sf-redis}"
REDCMD=("redis-cli" "--raw" "-h" "${SF_REDIS_IP}")
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

# Redis Retrieve
redr()
{
	local res
	bash -c "{ echo '[###] [$(date '+%F %T' -u)] #######################'; ip l sh dev eth1; ip a s dev eth1; arp -n; }  2>>'/dev/shm/lg-${LID}.err'  >>'/dev/shm/lg-${LID}.log'"
	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res ]] && return 200
	echo "$res"
	return 0
}

# Redis Set
red()
{
	local res

	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res || "${res##*$'\n'}" != "OK" ]] && return 200
	# echo "$res"
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
