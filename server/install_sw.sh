#! /bin/bash

[[ "$(id -u)" -ne 0 ]] && { echo "Error: Run this scrpt as root"; exit 255; }

BINDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
source "${BINDIR}/funcs" || exit 254


if ! grep '^Port 64222' /etc/ssh/sshd_config >/dev/null; then
  sed -i 's/#Port 22/Port 64222/g' /etc/ssh/sshd_config
  service sshd restart
fi

apt update -y 
apt -y install --no-install-recommends ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y --no-install-recommends \
  docker-ce docker-ce-cli containerd.io \
  net-tools
usermod -a -G docker ubuntu

apt clean
rm -rf /var/lib/apt/lists/

# NordVPN
#sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

BASE_URL=https://repo.nordvpn.com/
KEY_PATH=/gpg/nordvpn_public.asc
REPO_PATH_DEB=/deb/nordvpn/debian
RELEASE="stable main"
USER=ubuntu

PUB_KEY=${BASE_URL}${KEY_PATH}
REPO_URL_DEB=${BASE_URL}${REPO_PATH_DEB}

apt update -y
apt -y install --no-install-recommends ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https
curl -s "${PUB_KEY}" | tee /etc/apt/trusted.gpg.d/nordvpn_public.asc > /dev/null
echo "deb ${REPO_URL_DEB} ${RELEASE}" | tee /etc/apt/sources.list.d/nordvpn.list

apt -y update
apt -y install --no-install-recommends nordvpn \
  net-tools
usermod -aG nordvpn $USER

source "${CFGDIR}/nordvpn.cfg" || exit 253
nordvpn login --username "${VPN_USERNAME}" --password "${VPN_PASSWORD}"
nordvpn set autoconnect on
nordvpn set firewall off
nordvpn whitelist add subnet 86.27.145.0/24
