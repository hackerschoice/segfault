#! /bin/bash

CY="\e[1;33m" # yellow
CG="\e[1;32m" # green
CR="\e[1;31m" # red
CC="\e[1;36m" # cyan
CB="\e[1;34m" # blue
CM="\e[1;35m" # magenta
CW="\e[1;37m" # white
CF="\e[2m"    # faint
CN="\e[0m"    # none

CBG="\e[42;1m" # Background Green

# night-mode
CDY="\e[0;33m" # yellow
CDG="\e[0;32m" # green
CDR="\e[0;31m" # red
CDC="\e[0;36m" # cyan
CDM="\e[0;35m" # magenta

CUL="\e[4m"


echo -e "ERROR: Cryptostorm keeps changing its API. We cant keep up. The best way to find our your keys is
to go to https://cryptostorm.is/wireguard and then create a CONFIG string that looks like this:
${CDC}CONFIG${CN}=${CDG}auto:::PRIVATE_KEY:::PSK:::MYIP${CN}"



ERREXIT()
{
	local code
	code="$1"

	shift 1
	echo >&2 -e "${CDR}ERROR:${CN} $*"
	exit "$code"
}

[[ -z ${TOKEN} ]] && ERREXIT 255 "TOKEN= not set"

[[ -z $PRIVATE_KEY ]] && PRIVATE_KEY="$(wg genkey)"

PUBLIC_KEY="$(echo "${PRIVATE_KEY}" | wg pubkey)"

RES="$(curl -fsSL -X POST -F token="${TOKEN}" -F mode=paid -F pubkey="${PUBLIC_KEY}" https://cryptostorm.is/wireguard)"
echo "$RES" >/tmp/output.log # DEBUGGING

grep "That token is limited to" /tmp/output.log >/dev/null && ERREXIT 250 "All tokens used. Check ${CB}${CUL}https://cryptostorm.is/wireguard_man${CN}"

YOUR="$(grep '^Your ' /tmp/output.log)"
YOUR="${YOUR%%<*}"
PSK="${YOUR%%$'\n'*}"  # first line
PSK="${PSK#*\: }"

# "Your IP: 10.10.17.119</pre>""
MYIP="${YOUR##*$'\n'}"  # Last line
MYIP="${MYIP#*\: }"
MYIP="${MYIP%%[^0-9\.]*}"

[[ -z $MYIP ]] && ERREXIT 254 "Could not get IP address from CryptoStorm..."

cd /etc/wireguard
str="$(echo cs-*.conf)"
str="${str//cs-/}"
NODES="${str//\.conf/}"

echo -e "PRIVATE_KEY=${PRIVATE_KEY}"
echo -e "PSK=${PSK}"
echo -e "ADDRESS=${MYIP}"
echo -e "${CDC}CONFIG${CN}=${CDG}auto:::${PRIVATE_KEY}:::${PSK}:::${MYIP}${CN}"
echo -e "--> The fastest server is picked automatically. Otherwise replace"
echo -e "--> \`auto\` with \`iceland\` or any other server name."

