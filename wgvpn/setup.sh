#! /bin/bash

set -e

sed 's/\(^[^#].*net.ipv4.conf.all.src_valid_mark.*\)/#\1/g' -i /usr/bin/wg-quick

umask 077
[[ ! -d /etc/wireguard ]] && mkdir /etc/wireguard
cd /etc/wireguard
# Create configuration stubs of all CryptoStorm servers
echo "@@PRIVATEKEY@@" >privatekey
echo "@@PUBLICKEY@@" >publickey
wget --no-verbose https://cryptostorm.is/wg_confgen.txt -O /tmp/confgen.sh
chmod +x /tmp/confgen.sh
/tmp/confgen.sh "@@PSK@@" "@@ADDRESS@@"
rm -f privatekey publickey
mv /etc/wireguard /etc/wireguard-cryptostorm
ln -s /dev/shm/wireguard /etc/wireguard
ln -s /bin/true /sbin/resolvconf

for fn in /etc/wireguard-cryptostorm/cs-*.conf; do
	loc="${fn#*cs-}"
	loc="${loc%%.*}"
	[[ -z $loc ]] && continue
	[[ $loc == "la" ]] && loc="Los Angeles"
	[[ $loc == "nc" ]] && loc="North Carolina"
	[[ $loc == "sk" ]] && loc="South Korea"
	[[ $loc == "dc" ]] && loc="Washington DC"
	echo -e "# GEOIP=${loc^}" >>"${fn}"
	# Some DC's now filter 443/UDP. Use 5182/UDP instead. 
	sed 's/:443/:5182/g' -i "$fn"
done

# Mullvad stubs
echo "Creating Mullvad stubs"
[[ ! -d /etc/wireguard-mullvad ]] && mkdir -p /etc/wireguard-mullvad 
curl -fsSL https://api.mullvad.net/public/relays/wireguard/v1/ -o /etc/wireguard-mullvad/mullvad.json || exit 255


# For each single hostname create a config file that contains the
# COUNTRY + CITY + PUBLIC_KEY + IP
# FIXME: Make this faster converting (e.g. get better at jq)
cd /etc/wireguard-mullvad
IFS=$'\n'
arr=($(jq -r '.countries[].cities[].relays[].hostname' mullvad.json))
for hn in "${arr[@]}"; do
	[[ "$hn" =~ [^[:alnum:]-] ]] && { echo >&2 "BAD HOSTNAME ${hn}"; continue; }

	# countrycode=$(jq -r '.countries[] | select(any(.cities[].relays[]; .hostname == "'"$hn"'")) | .code' mullvad.json)
	country=$(jq -r '.countries[] | select(any(.cities[].relays[]; .hostname == "'"$hn"'")) | .name' mullvad.json)
	city=$(jq -r '.countries[].cities[] | select(any(.relays[]; .hostname == "'"$hn"'")) | .name' mullvad.json)

	# Extract relay
	relay=$(jq '.countries[].cities[].relays[] | select(.hostname == "'"$hn"'")' mullvad.json)
	ip=$(echo "$relay" | jq -r .ipv4_addr_in)
	key=$(echo "$relay" | jq -r .public_key)

	# Seattle, WA => Seattle
	city="${city%%,*}"

	# Singapore/Singapore => Singapore
	# Hong Kong/Hong Kong => Hong Kong
	[[ "$country" == "$city" ]] && unset city

	unset GEOIP
	[[ -n $city ]] && GEOIP="${city}/"
	GEOIP+="${country}"
	GEOIP="${GEOIP//[^[:alnum:].-_ \/]}"
	echo -e "\
DNS = 10.64.0.1\n\
PublicKey = ${key}\n\
Endpoint = ${ip}\n\
# GEOIP=${GEOIP}" >"./${hn}.conf"
done
