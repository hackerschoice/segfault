
DevByIP()
{
	local dev

	[[ -z $1 ]] && { echo >&2 "Paremter missing"; return 255; }
	dev=$(ip addr show | grep -F "inet $1")
	dev="${dev##* }"
	[[ -z $dev ]] && { echo -e >&2 "DEV not found for ip '$1'"; return 255; }
	echo "$dev"
}


GetMainIP()
{
	local arr
	arr=($(ip route get 8.8.8.8))
	echo "${arr[6]}"
}

tc_set()
{
	local dev
	local rate
	local key
	dev=$1
	rate=$2
	key=$3

	tc qdisc add dev "${dev}" root handle 1: htb && \
	tc class add dev "${dev}" parent 1: classid 1:10 htb rate "${rate}" && \
	tc filter add dev "${dev}" parent 1: protocol ip matchall flowid 1:10 && \
	tc qdisc add dev "${dev}" parent 1:10 handle 11: sfq && \
	tc filter add dev "${dev}" parent 11: handle 11 flow hash keys "${key}" divisor 1024
}
