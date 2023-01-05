
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
