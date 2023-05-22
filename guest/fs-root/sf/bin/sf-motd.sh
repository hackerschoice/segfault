#! /bin/bash

# BINDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
# shellcheck disable=SC1091
source "/sf/bin/funcs.sh" 2>/dev/null
# shellcheck disable=SC1091
source "/config/guest/vpn_status" 2>/dev/null

print_ssh_access()
{
	local key_suffix

	key_suffix="sf-${SF_FQDN//./-}"
	echo 1>&2 -e "\
:Cut & Paste these lines to your workstation's shell to retain access:
######################################################################
${CDC}cat >~/.ssh/id_${key_suffix} ${CDR}<<__EOF__
${CN}${CF}$(<"/config/guest/id_ed25519")
${CDR}__EOF__
${CDC}cat >>~/.ssh/config ${CDR}<<${CDR}__EOF__
${CN}${CF}host ${SF_HOSTNAME,,}
    User root
    HostName ${SF_FQDN}
    IdentityFile ~/.ssh/id_${key_suffix}
    SetEnv SECRET=${SF_SEC}
${CDR}__EOF__
${CDC}chmod 600 ~/.ssh/config ~/.ssh/id_${key_suffix}${CN}
######################################################################
Thereafter use these commands:
--> ${CDC}ssh  ${SF_HOSTNAME,,}${CN}
--> ${CDC}sftp ${SF_HOSTNAME,,}${CN}
--> ${CDC}scp  ${SF_HOSTNAME,,}:stuff.tar.gz ~/${CN}
--> ${CDC}sshfs -o reconnect ${SF_HOSTNAME,,}:/sec ~/sec ${CN}
----------------------------------------------------------------------"
}

mk_vpn()
{
	if [[ -z $IS_VPN_CONNECTED ]]; then
		if source "/config/guest/vpn_status.direct" 2>/dev/null; then
			str="${SFVPN_EXIT_IP}                   "
			VPN_DST="VPN Exit Node     : ${CDG}${str:0:15}"
			[[ -n $SFVPN_GEOIP ]] && VPN_DST+=" ${CF}(${SFVPN_GEOIP})${CN}"
			VPN_DST+=" ${CR}>>> DIRECT <<<${CF} (no VPN)${CN}"$'\n'
		else
			VPN_DST="VPN Exit Node     : ${CR}TOR ${CF}(no VPN)${CN}"$'\n'
		fi
	else
		i=0
		while [[ $i -lt ${#VPN_GEOIP[@]} ]]; do
			str="Exit ${VPN_PROVIDER[$i]}                          "
			VPN_DST+="${str:0:17} : "
			str="${VPN_EXIT_IP[$i]}                 "
			VPN_DST+="${CDG}${str:0:15}"
			str="${VPN_GEOIP[$i]}"
			[[ ! -z $str ]] && VPN_DST+=" ${CF}(${str})"
			VPN_DST+="${CN}"$'\n'
			((i++))
		done
	fi
}

[[ -n $SF_IS_NEW_SERVER ]] && _IS_SHOW_MORE=1
[[ "${0##*/}" == "info" ]] && _IS_SHOW_MORE=1
[[ -n $_IS_SHOW_MORE ]] && print_ssh_access

if [[ -e "/config/self/wgname" ]]; then
	VPN_DST="Exit Wireguard    : ${CDY}$(</config/self/wgname)${CN}${CF} [to disable: curl rpc/net/down]${CN}"$'\n'
else
	mk_vpn
fi

[[ -f "/config/self/ip" ]]    &&    YOUR_IP="$(</config/self/ip)"
[[ -f "/config/self/geoip" ]] && YOUR_GEOIP="$(</config/self/geoip)"

loc="${YOUR_IP:-UNKNOWN}                 "
loc="${loc:0:15}"
[[ -n $YOUR_GEOIP ]] && loc+=" ${CF}($YOUR_GEOIP)"

[[ -f /config/self/reverse_ip ]] && {
	IPPORT="${CDY}$(</config/self/reverse_ip):$(</config/self/reverse_port)"
	[[ -f /config/self/reverse_geoip ]] && IPPORT+=" ${CF}($(<config/self/reverse_geoip))"
}
[[ -z $IPPORT ]] && IPPORT="${CDR}N/A${CN}"

echo -en "\
Your workstation  : ${CDY}${loc}${CN}
Reverse Port      : ${IPPORT}${CN}
${VPN_DST}"

# All below should only be displayed if user types 'info' or a newly created server.
[[ -z $_IS_SHOW_MORE ]] && {
	echo -e "\
Hint              : ${CDC}Type ${CC}info${CDC} for more details.${CN}"
	exit
}
unset _IS_SHOW_MORE

echo -e "\
TOR Proxy         : ${CDG}${SF_TOR_IP:-UNKNOWN}:9050${CN}"

str="${SF_HOSTNAME}                            "
echo -e "\
Shared storage    : ${CDM}/everyone/${str:0:16} ${CF}(encrypted)${CN}
Your storage      : ${CDM}/sec                       ${CF}(encrypted)${CN}"
[[ -e /config/guest/onion_hostname-80 ]] && {
	echo -e "\
Your Onion WWW    : ${CDM}/onion                     ${CF}(encrypted)${CN}"

	echo -e "\
Your Web Page     : ${CB}${CUL}http://$(cat /config/guest/onion_hostname-80)/${SF_HOSTNAME,,}/${CN}"
}
	# HERE: Only display this ONCE when a new server is created.
[[ -n $SF_SSH_PORT ]] && PORTSTR=" -p${SF_SSH_PORT} "
echo -e "\
SSH               : ${CC}ssh${CDC} -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\"${PORTSTR} ${CR}${CF}\\ ${CDC}\n\
                       ${SF_USER:-UNKNOWN}@${SF_FQDN:-UNKNOWN}${CN}"

[[ -e /config/guest/onion_hostname-22 ]] && {
	echo -e "\
SSH (TOR)         : ${CC}torsocks ssh${CN}${CDC} -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" ${CR}${CF}\\ ${CDC}\n\
                       ${SF_USER:-UNKNOWN}@$(cat /config/guest/onion_hostname-22)${CN}"
}
[[ -e /config/guest/gsnc-access-22.txt ]] && {
	echo -e "\
SSH (gsocket)     : ${CC}gsocket -s $(cat /config/guest/gsnc-access-22.txt) ssh${CDC} -o \"SetEnv SECRET=${SF_SEC:-UNKNOWN}\" ${CR}${CF}\\ ${CDC}\n\
                       ${SF_USER:-UNKNOWN}@${SF_FQDN%.*}.gsocket${CN}"
}
str="SECRET            : ${CDY}${SF_SEC}"
[[ -n $SF_IS_LOGINSHELL ]] && str+=" ${CRY}<<<  WRITE THIS DOWN  <<<"
echo -e "${str}${CN}"
