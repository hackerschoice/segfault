
# SF_REDIS_SERVER=172.20.2.254
SF_REDIS_SERVER="${SF_REDIS_SERVER:-sf-redis}"
REDCMD=("redis-cli" "--raw" "-h" "${SF_REDIS_SERVER}")
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

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
