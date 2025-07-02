

# Wait 10 seconds for handshake to complete
wait_for_handshake()
{
	local n
	local dev
	dev="$1"

	n=0
	while :; do
	  last=$(wg show "${dev}" latest-handshakes 2>/dev/null)
	  last="${last##*[[:space:]]}"
	  [[ $last -gt 0 ]] && break

	  ((n++))
	  [[ $n -gt 20 ]] && return 255 # FALSE
	  sleep 0.5
	done

	return 0 # TRUE
}

# Check VPN needs to be done a few times as sometimes it fails...
# check_vpn [mullvad/cryptostorm]
check_vpn()
{
	# local provider="${1,,}"
	local n
	local dev
	# local bad
	local err=0
	local sleep_timer
	sleep_timer=5
	dev="${2:-wg0}"

	# can happen if admin issued 'wg-quick down wg0'
	wg show "$dev" >/dev/null 2>/dev/null || {
		# Known bug: if wg0 disappears (ip link del wg0) then WG wont call
		# the POST_DOWN script. We ignore this case.
		echo "[$(date -Iseconds)] VPN check failed ('$dev' does not exists)."
		return 200
	}

	while :; do
		# if [[ "${provider}" == "mullvad" ]]; then
		# 	[[ "$(curl -SsfL --max-time 5 https://am.i.mullvad.net/connected)" == *"are connected"* ]] && return 0
		# elif [[ "${provider}" == "cryptostorm" ]]; then
		# 	[[ "$(curl -SsfL --max-time 5 https://cryptostorm.is/test.cgi)" == *"IS cryptostorm"* ]] && return 0
		# else
		# 	# echo >&2 "WARNING: Provider check '${provider}' not known"
		# 	# Exit with error if a single packet is missed.
		# 	ping -4 -c 5 -i 1 -W 2 -w 5 -A -q 1.1.1.1 >/dev/null && return 0
		# fi
		ping -n -c 2 -i 1 -W 2 -w 5 -q 1.1.1.1 >/dev/null 2>/dev/null && return 0
		
		((err++))
		echo "[$(date -Iseconds)] VPN check failed. Strike #${err}."
		[[ $err -gt 3 ]] && return 255
		sleep $sleep_timer
		sleep_timer=15
	done

	return 0
}
