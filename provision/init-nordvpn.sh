#! /bin/bash

# Install NordVPN and configure it.

SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
source "${SFI_SRCDIR}/provision/system/funcs" || exit 255
NEED_ROOT

# Exit if already installed (nordvpn status return TRUE even when not connected)
nordvpn status 2>/dev/null && { WARN 1 "NordVPN already installed. SKIPPING."; exit 0; }
# command -v nordvpn >/dev/null && { WARN 23 "NordVPN already installed. SKIPPING"; exit 0; }

[[ -z $SF_VPN_LOGIN ]] && ERREXIT 255 "SF_VPN_LOGIN= not set"
[[ -z $SF_VPN_PASSWORD ]] && ERREXIT 254 "SF_VPN_PASSWORD= not set"
[[ -z $SF_HOST_USER ]] && ERREXIT 253 "SF_HOST_USER= not set"


# AWS ubuntu 22 doesnt have this symlink
[[ ! -e /usr/bin/systemd-resolve ]] && [[ /usr/bin/resolvectl ]] && ln -s resolvectl /usr/bin/systemd-resolve

if ! command -v nordvpn >/dev/null; then
	BASE_URL=https://repo.nordvpn.com/
	KEY_PATH=/gpg/nordvpn_public.asc
	REPO_PATH_DEB=/deb/nordvpn/debian
	RELEASE="stable main"

	PUB_KEY=${BASE_URL}${KEY_PATH}
	REPO_URL_DEB=${BASE_URL}${REPO_PATH_DEB}

	apt update -y
	apt -y install --no-install-recommends ca-certificates \
	  curl \
	  gnupg \
	  lsb-release \
	  apt-transport-https

	[[ -s /etc/apt/trusted.gpg.d/nordvpn_public.asc ]] || {
		curl -s "${PUB_KEY}" | tee /etc/apt/trusted.gpg.d/nordvpn_public.asc >/dev/null
		[[ -s /etc/apt/trusted.gpg.d/nordvpn_public.asc ]] || ERREXIT
	}

	[[ -s /etc/apt/sources.list.d/nordvpn.list ]] || {
		echo "deb ${REPO_URL_DEB} ${RELEASE}" | tee /etc/apt/sources.list.d/nordvpn.list >/dev/null
		[[ -s /etc/apt/sources.list.d/nordvpn.list ]] || ERREXIT
	}

	apt -y update
	apt -y install --no-install-recommends nordvpn \
		net-tools
fi

usermod -aG nordvpn "${SF_HOST_USER}"

nordvpn login --username "${SF_VPN_LOGIN}" --password "${SF_VPN_PASSWORD:-PASSWORD-MISSING}"

# Find out source IP to whitelist
[[ -z $SF_IP_WHITELIST ]] && {
	SF_IP_WHITELIST="$(echo "$SSH_CONNECTION" | cut -f1 -d" ")"
	[[ -z $SF_IP_WHITELIST ]] && ERREXIT 253 "SF_VPN_WHITELIST= not set."
}

nordvpn whitelist add subnet "${SF_IP_WHITELIST}/32" || ERREXIT 254 "SF_IP_WHITELIST=${SF_IP_WHITELIST}/32"
# We poll in sf-fw.sh until NordVPN is connected.
# nordvpn set autoconnect on
# Do not allow NordVPN to manage my firewall
nordvpn set firewall off



