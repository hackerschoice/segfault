#! /bin/bash

# FIXME redis-cli on sf-master does not know -e (Ohh. $? on ERROR will be 0)
# REDCMD=("redis-cli" "-e" "--raw" "-s" "/redis-sock/redis.sock")
REDCMD=("redis-cli" "--raw" "-s" "/redis-sock/redis.sock")
export REDISCLI_AUTH="${SF_REDIS_AUTH}"

# Redis Retrieve
redr()
{
	local res
	
	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res ]] && return 200
	echo "$res"
	return 0
}

# Quiete retrieve
redq()
{
	local res
	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res ]] && return 200
	return 0
}

# Redis Set, Last line is "OK" on success.
red()
{
	local res

	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res || "${res##*$'\n'}" != "OK" ]] && return 200
	return 0
}

# Redis Set, last line is "1" on success.
red1()
{
	local res

	res=$("${REDCMD[@]}" "$@") || return 255
	[[ -z $res || "${res##*$'\n'}" != "1" ]] && return 200
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
