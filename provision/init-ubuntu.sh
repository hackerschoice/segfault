#! /bin/bash

# Installs & Bootstraps 'Segfault Hosting Solution' onto a vanilla Linux Server.
#
# See https://www.thc.org/segfault/deploy to install with a single command.
#
# Environment variables:
#     SF_HOST_USER   - The user on the server under which 'segfault' is installed. (e.g. /home/ubuntu)
#     SF_NO_INTERNET - DEBUG: Runs script without Internet

SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
source "${SFI_SRCDIR}/provision/system/funcs" || exit 255
NEED_ROOT

DEBUGF "SFI_SRCDIR=${SFI_SRCDIR}"

SUDO_SF()
{
  DEBUGF "${SF_HOST_USER} $*"
  sudo -u "${SF_HOST_USER}" bash -c "$*"
}

# add_service <.service name> <.sh file>
add_service()
{
  local sname
  sname="${1}"
  local is_need_reload

  cp "${SFI_SRCDIR}/provision/system/${sname}.sh" "${SF_BASEDIR}/system/${sname}.sh"
  chmod 750 "${SF_BASEDIR}/system/${sname}.sh"

  [[ -f "/etc/systemd/system/${sname}.service" ]] && is_need_reload=1
  cp "${SFI_SRCDIR}/provision/${sname}.service" "/etc/systemd/system/${sname}.service"
  chmod 640 "/etc/systemd/system/${sname}.service"
  sed -i "s/@SF_BASEDIR@/${SF_BASEDIR_ESC}/" "/etc/systemd/system/${sname}.service"
  # If service is already installed then a 'daemon-reload' & 'reload' should be enough.
  if [[ -n $is_need_reload ]]; then
    DEBUGF "RESTARTING SERVICE ${sname}.service"
    systemctl daemon-reload
    systemctl stop "${sname}"
    systemctl start "${sname}"
    # systemctl reload "${sname}"
  else
    systemctl enable "${sname}"
    systemctl start "${sname}"
  fi
}

# INIT: Find valid user to use for installation
[[ -z $SF_HOST_USER ]] && {
  # EC2 default is 'ubuntu'. Fall-back to 'sf-user' otherwise.
  id -u ubuntu &>/dev/null && SF_HOST_USER="ubuntu" || SF_HOST_USER="sf-user"
  export SF_HOST_USER # init-nordvpn.sh etc needs this.
}

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
  [[ -z $SF_NO_INTERNET ]] && apt update -y
  [[ -z $SF_NO_INTERNET ]] && apt -y install --no-install-recommends ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https

  [[ -s /usr/share/keyrings/docker-archive-keyring.gpg ]] || {
    rm -rf /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null # Delete in case it is zero bytes
    [[ -z $SF_NO_INTERNET ]] && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  }

  [[ -z $SF_NO_INTERNET ]] && apt-get update -y
}

### Install Docker and supporting tools
[[ -z $SF_NO_INTERNET ]] && { apt-get install -y --no-install-recommends \
  docker-ce docker-ce-cli containerd.io docker-compose \
  net-tools make || ERREXIT; }

# SSHD's login user (normally 'root' with uid 1000) needs to start docker instances
usermod -a -G docker "${SF_HOST_USER}"

# NOTE: Only needed if source is mounted into vmbox (for testing)
[[ "$(stat -c %G /segfault 2>/dev/null)" = "vboxsf" ]] && usermod -a -G vboxsf "${SF_HOST_USER}"

# SNAPSHOT #2 (2022-05-09)

# Create SSH-KEYS and directories.
[[ -d "${SF_BASEDIR}/config/db" ]] || SUDO_SF "mkdir -p \"${SF_BASEDIR}/config/db\""
[[ -d "${SF_BASEDIR}/config/etc/ssh" ]] || {
  IS_NEW_SSH_HOST_KEYS=1
  SUDO_SF "mkdir -p \"${SF_BASEDIR}/config/etc/ssh\" && ssh-keygen -A -f \"${SF_BASEDIR}\"/config"
}
[[ -f "${SF_BASEDIR}/config/etc/ssh/id_ed25519" ]] || {
  IS_NEW_SSH_LOGIN_KEYS=1
  SUDO_SF "ssh-keygen -q -t ed25519 -C \"\" -N \"\" -f \"${SF_BASEDIR}/config/etc/ssh/id_ed25519\""
}

# Create guest, encfs and other docker images.
[[ -z $SF_NO_INTERNET ]] && { SUDO_SF "cd ${SFI_SRCDIR} && make" || exit; }

# Find out my own hostname unless SF_FQDN is set (before NordVPN is runnning)
[[ -z $SF_FQDN ]] && {
  # Find out my own hostname
  [[ -z $SF_NO_INTERNET ]] && {
    IP="$(curl ifconfig.me 2>/dev/null)"
    HOST="$(host "$IP")" && HOST="$(echo "$HOST" | sed -E 's/.*name pointer (.*)\.$/\1/g')" || HOST="$(hostname -f)"
  }

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
[[ -e "${ENV}" ]] && { IS_USING_EXISTING_ENV_FILE=1; } || {
  SUDO_SF "cp \"${SFI_SRCDIR}/provision/env.example\" \"${ENV}\" && \
  sed -i 's/^SF_BASEDIR.*/SF_BASEDIR=${SF_BASEDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/^SF_SRCDIR.*/SF_SRCDIR=${SF_SRCDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/.*SF_FQDN.*/SF_FQDN=${SF_FQDN_ESC}/' \"${ENV}\" && \
  sed -i 's/PORT=.*/PORT=${SF_SSH_PORT}/' \"${ENV}\"" || ERREXIT 120 failed
}

DOCKER_COMPOSE_CMD="docker-compose up --build --force-recreate --quiet-pull -d"
(cd "${SFI_SRCDIR}" && docker ps) | grep sf-host >/dev/null && IS_DOCKER_ALREADY_RUNNING=1 || {
  (cd "${SFI_SRCDIR}" && $DOCKER_COMPOSE_CMD) || ERREXIT
}


# This directory will be mounted[read-only] into sf-guest (user's shell)
[[ -d "${SF_BASEDIR}/guest" ]] || SUDO_SF "mkdir -p \"${SF_BASEDIR}/guest\"" || ERREXIT
# Copy supporting files that sf-guest needs (like /etc/skel, sf-motd, etc).
SUDO_SF "cp -r \"${SFI_SRCDIR}/guest/sf-guest\" \"${SF_BASEDIR}/guest\""
SUDO_SF "mkdir -p \"${SF_BASEDIR}/guest/sf-guest/log\""

# Set up NordVPN
${SFI_SRCDIR}/provision/init-nordvpn.sh || WARN 2 "Skipping NordVPN"

# Set up monitor and firewall scripts for NordVPN
command -v nordvpn >/dev/null && {
  DEBUGF "Installing Segfault Services..."
  [[ -z $SF_BASEDIR_ESC ]] && ERREXIT 11 "SF_BASEDIR_ESC not set???"
  # Create supporting directories
  mkdir "${SF_BASEDIR}/system" 2>/dev/null

  ### Add support funcs
  cp "${SFI_SRCDIR}/provision/system/funcs" "${SF_BASEDIR}/system/funcs" && \
    chmod 644 "${SF_BASEDIR}/system/funcs"

  ### Set up NordVPN Status-Update/Monitoring script
  add_service "sf-monitor"
  ### Set up firewall script (for NordVPN)
  add_service "sf-fw"
}

echo -e "***${CG}SUCCESS${CN}***"
[[ -z $IS_USING_EXISTING_ENV_FILE ]] || WARN 4 "Using existing .env file (${ENV})"
[[ -z $IS_DOCKER_ALREADY_RUNNING ]] || {
  WARN 5 "Docker docker-compose failed. Please run:"
  INFO "(cd \"${SFI_SRCDIR}\" && docker-compose down && \\
    ${DOCKER_COMPOSE_CMD})"
}
#${SF_BASEDIR}/config/etc/ssh/id_ed25519
INFO "Directory           : ${CC}${SF_BASEDIR}${CN}"
INFO "Access with         : ${CC}ssh -p ${SF_SSH_PORT} root@${SF_FQDN}${CN}"
[[ -z $IS_NEW_SSH_HOST_KEYS ]] &&  STR="existing" || STR="${CR}***NEW***${CN}"
INFO "SSH Login Keys      : $(cd "${SF_BASEDIR}/config" && md5sum etc/ssh/ssh_host_ed25519_key) (${STR})"
[[ -z $IS_NEW_SSH_LOGIN_KEYS ]] &&  STR="existing" || STR="${CR}***NEW***${CN}"
INFO "SSH Login Keys      : $(cd "${SF_BASEDIR}/config" && md5sum etc/ssh/id_ed25519) (${STR})"





