#! /bin/bash

# Installs & Bootstraps 'Segfault Hosting Solution' onto a vanilla Linux Server.
#
# See https://www.thc.org/segfault/deploy to install with a single command.
#
# Environment variables:
#     SF_HOST_USER - The user on the server under which 'segfault' is installed. (e.g. /home/ubuntu)

SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
source "${SFI_SRCDIR}/provision/funcs" || exit 255
NEED_ROOT

DEBUGF "SFI_SRCDIR=${SFI_SRCDIR}"

SUDO_SF()
{
  sudo -u "${SF_HOST_USER}" bash -c "$*"
}

# INIT: Find valid user to use for installation
[[ -z $SF_HOST_USER ]] && {
  # EC2 default is 'ubuntu'. Fall-back to 'sf-user' otherwise.
  id -u ubuntu &>/dev/null && SF_HOST_USER="ubuntu" || SF_HOST_USER="sf-user"
}
export SF_HOST_USER # init-nordvpn.sh etc needs this.

# Create user if it does not exist
useradd "${SF_HOST_USER}" -s /bin/bash 2>/dev/null
[[ -d "/home/${SF_HOST_USER}" ]] || {
  cp -a /etc/skel "/home/${SF_HOST_USER}"
  chown -R "${SF_HOST_USER}:${SF_HOST_USER}" "/home/${SF_HOST_USER}"
}

SF_HOST_USER_ID="$(id -u "$SF_HOST_USER")"
DEBUGF "SF_HOST_USER_ID=${SF_HOST_USER_ID} (SF_HOST_USER=${SF_HOST_USER})"

# INIT: Find good location for dynamic configuration
[[ -z $SF_BASEDIR ]] && {
  SUDO_SF "mkdir -p ~/segfault"
  SF_BASEDIR="$(cd "/home/${SF_HOST_USER}/segfault" || exit; pwd)"
}
DEBUGF "SF_BASEDIR=${SF_BASEDIR}"

[[ ! -d "${SF_BASEDIR}/config" ]] && SUDO_SF "mkdir \"${SF_BASEDIR}/config\""
[[ ! -d "${SF_BASEDIR}/config/db" ]] && SUDO_SF "mkdir \"${SF_BASEDIR}/config/db\""

# Configure SSHD
[[ -z $SF_SSH_PORT ]] && SF_SSH_PORT=22
[[ -z $SF_SSH_PORT_MASTER ]] && SF_SSH_PORT_MASTER=64222

# Move original SSH server out of the way...
[[ "$SF_SSH_PORT" -eq 22 ]] && {
  sed -i "s/#Port ${SF_SSH_PORT}/Port ${SF_SSH_PORT_MASTER}/g" /etc/ssh/sshd_config
  DEBUGF "Restarting SSHD"
  service sshd restart
}

# Add docker repository to APT
[[ -s /usr/share/keyrings/docker-archive-keyring.gpg ]] || {
  apt update -y
  apt -y install --no-install-recommends ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https

  [[ -s /usr/share/keyrings/docker-archive-keyring.gpg ]] || {
    rm -rf /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null # Delete in case it is zero bytes
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  }

  apt-get update -y
}

apt-get install -y --no-install-recommends \
  docker-ce docker-ce-cli containerd.io docker-compose \
  net-tools make || ERREXIT

# SSHD's login user (normally 'root' with uid 1000) needs to start docker instances
usermod -a -G docker "${SF_HOST_USER}"

# NOTE: Only needed if source is mounted into vmbox (for testing)
[[ "$(stat -c %G /segfault 2>/dev/null)" = "vboxsf" ]] && usermod -a -G vboxsf "${SF_HOST_USER}"

# SNAPSHOT #2 (2022-05-09)

# Create guest, encfs and other docker images.
SUDO_SF "cd ${SFI_SRCDIR} && make" || exit

# Create SSH-KEYS and directories.
[[ -d "${SF_BASEDIR}/config/db" ]] || SUDO_SF "mkdir -p \"${SF_BASEDIR}/config/db\""
[[ -d "${SF_BASEDIR}/config/etc/ssh" ]] || SUDO_SF "mkdir -p \"${SF_BASEDIR}/config/etc/ssh\" && ssh-keygen -A -f ~/segfault/config"
[[ -f "${SF_BASEDIR}/config/etc/ssh/id_ed25519" ]] || SUDO_SF "ssh-keygen -q -t ed25519 -C \"\" -N \"\" -f \"${SF_BASEDIR}/config/etc/ssh/id_ed25519\""

# Find out my own hostname unless SF_FQDN is set (before NordVPN is runnning)
[[ -z $SF_FQDN ]] && {
  # Find out my own hostname
  IP="$(curl ifconfig.me 2>/dev/null)"
  HOST="$(host "$IP")" && HOST="$(echo "$HOST" | sed -E 's/.*name pointer (.*)\.$/\1/g')" || HOST="$(hostname -f)"

  # To short or contains illegal characters? 
  [[ "$HOST" =~ ^[a-zA-Z0-9.-]{4,61}$ ]] || unset HOST

  SF_FQDN="${HOST:-UNKNOWN}"
  unset ip
  unset HOST
}

DEBUGF "SF_FQDN=${SF_FQDN}"
# Create '.env' file for docker-compose
SF_BASEDIR_ESC="${SF_BASEDIR//\//\\/}"
SF_SRCDIR_ESC="${SFI_SRCDIR//\//\\/}"
SF_FQDN_ESC="${SF_FQDN//\//\\/}"
ENV="${SFI_SRCDIR}/.env"
[[ -e "${ENV}" ]] && { WARN 4 "Using existing .env file"; } || {
  SUDO_SF "cp \"${SFI_SRCDIR}/provision/env.example\" \"${ENV}\" && \
  sed -i 's/^SF_BASEDIR.*/SF_BASEDIR=${SF_BASEDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/^SF_SRCDIR.*/SF_SRCDIR=${SF_SRCDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/.*SF_FQDN.*/SF_FQDN=${SF_FQDN_ESC}/' \"${ENV}\" && \
  sed -i 's/PORT=.*/PORT=${SF_SSH_PORT}/' \"${ENV}\"" || ERREXIT 120 failed
}

# SUDO_SF "cd ${SF_BASEDIR} && docker-compose -f \"${SFI_SRCDIR}/docker-compose.yml\" up -d --build --force-recreate --quiet-pull" || ERREXIT
cd ${SFI_SRCDIR} && docker-compose up -d --build --force-recreate --quiet-pull || ERREXIT

# This directory will be mounted[read-only] into sf-guest (user's shell)
[[ -d "${SF_BASEDIR}/guest" ]] || SUDO_SF "mkdir -p \"${SF_BASEDIR}/guest\"" || ERREXIT
# Copy supporting files that sf-guest needs (like /etc/skel, vpn_status, sf-motd, etc).
SUDO_SF "cp -r \"${SFI_SRCDIR}/guest/sf-guest\" \"${SF_BASEDIR}/guest\""

# Set up NordVPN
${SFI_SRCDIR}/provision/init-nordvpn.sh || WARN 2 "Skipping NordVPN"

# Set up monitor and firewall scripts for NordVPN
command -v nordvpn >/dev/null && {
  DEBUGF "Installing Segfault Services..."
  [[ -z $SF_BASEDIR_ESC ]] && ERREXIT 11 "SF_BASEDIR_ESC not set???"
  # Create supporting directories
  mkdir "${SF_BASEDIR}/system" 2>/dev/null

  ### Set up NordVPN Status-Update/Monitoring script
  cp "${SFI_SRCDIR}/system/sf-monitor.sh" "${SF_BASEDIR}/system/sf-monitor.sh"
  chmod 750 "${SF_BASEDIR}/system/sf-monitor.sh"

  cp "${SFI_SRCDIR}/provision/sf-monitor.service" /etc/systemd/system/sf-monitor.service
  chmod 640 /etc/systemd/system/sf-monitor.service
  sed -i "s/@SF_BASEDIR@/${SF_BASEDIR_ESC}/" /etc/systemd/system/sf-monitor.service
  systemctl enable sf-monitor 
  systemctl start sf-monitor

  ### Set up firewall script (for NordVPN)
  cp "${SFI_SRCDIR}/system/sf-fw.sh" "${SF_BASEDIR}/system/sf-fw.sh"
  chmod 750 "${SF_BASEDIR}/system/sf-fw.sh"

  cp "${SFI_SRCDIR}/provision/sf-fw.service" /etc/systemd/system/sf-fw.service
  chmod 640 /etc/systemd/system/sf-fw.service
  sed -i "s/@SF_BASEDIR@/${SF_BASEDIR_ESC}/" /etc/systemd/system/sf-fw.service
  systemctl enable sf-fw 
  systemctl start sf-fw

}




