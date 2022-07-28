#! /bin/bash

# Installs & Bootstraps 'Segfault Hosting Solution' onto a vanilla Linux Server.
#
# See https://www.thc.org/segfault/deploy to install with a single command.
#
# Environment variables:
#     SF_HOST_USER   - The user on the server under which 'segfault' is installed. (e.g. /home/ubuntu)
#     SF_NO_INTERNET - DEBUG: Runs script without Internet

SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
# shellcheck disable=SC1091
source "${SFI_SRCDIR}/provision/system/funcs" || exit 255
NEED_ROOT

DEBUGF "SFI_SRCDIR=${SFI_SRCDIR}"

SUDO_SF()
{
  DEBUGF "${SF_HOST_USER} $*"
  sudo -u "${SF_HOST_USER}" bash -c "$*"
}

install_docker()
{
  command -v docker >/dev/null && return

  # Add docker repository to APT
  if [[ ! -s /usr/share/keyrings/docker-archive-keyring.gpg ]]; then
    [[ -z $SF_NO_INTERNET ]] && apt update -y && apt -y install --no-install-recommends ca-certificates \
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
  fi

  ### Install Docker and supporting tools
  if [[ -z $SF_NO_INTERNET ]]; then
    apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-compose \
      net-tools make || ERREXIT
  fi
}

init_user()
{
  # INIT: Find valid user to use for installation
  [[ -z $SF_HOST_USER ]] && {
    # EC2 default is 'ubuntu'. Fall-back to 'sf-user' otherwise.
    id -u ubuntu &>/dev/null && SF_HOST_USER="ubuntu" || SF_HOST_USER="sf-user"
    export SF_HOST_USER
  }

  # Create user if it does not exist
  useradd "${SF_HOST_USER}" -s /bin/bash 2>/dev/null
  [[ -d "/home/${SF_HOST_USER}" ]] || {
    cp -a /etc/skel "/home/${SF_HOST_USER}"
    chown -R "${SF_HOST_USER}:${SF_HOST_USER}" "/home/${SF_HOST_USER}"
  }

  SF_HOST_USER_ID="$(id -u "$SF_HOST_USER")"
  DEBUGF "SF_HOST_USER_ID=${SF_HOST_USER_ID} (SF_HOST_USER=${SF_HOST_USER})"
}

init_host_sshd()
{
  local port

  # Configure SSHD
  [[ -f /etc/ssh/sshd_config ]] || return

  port=${SF_SSH_PORT:-22}
  [[ -z $SF_SSH_PORT_MASTER ]] && SF_SSH_PORT_MASTER=64222

  # Move original SSH server out of the way...
  [[ "${port}" -eq 22 ]] && grep "Port 22" /etc/ssh/sshd_config >/dev/null && {
    sed -i "s/#Port ${port}/Port ${SF_SSH_PORT_MASTER}/g" /etc/ssh/sshd_config
    DEBUGF "Restarting SSHD on port ${SF_SSH_PORT_MASTER}"
    service sshd restart
    IS_SSH_GOT_MOVED=1
  }
}

init_basedir()
{
  # INIT: Find good location for dynamic configuration
  [[ -z $SF_BASEDIR ]] && {
    SUDO_SF "mkdir -p ~/segfault"
    SF_BASEDIR="$(cd "/home/${SF_HOST_USER}/segfault" || exit; pwd)"
  }
  DEBUGF "SF_BASEDIR=${SF_BASEDIR}"

  [[ ! -d "${SF_BASEDIR}/config" ]] && SUDO_SF "mkdir \"${SF_BASEDIR}/config\""
  [[ ! -d "${SF_BASEDIR}/config/db" ]] && SUDO_SF "mkdir \"${SF_BASEDIR}/config/db\""
}

init_config_run_sfbin()
{
  # Copy nginx.conf
  [[ ! -d "${SF_BASEDIR}/config/etc/nginx" ]] && SUDO_SF "cp -r \"${SFI_SRCDIR}/config/etc/nginx\" \"${SF_BASEDIR}/config/etc\""

  # Copy Traffic Control (tc) config
  [[ ! -d "${SF_BASEDIR}/config/etc/tc" ]] && SUDO_SF "cp -r \"${SFI_SRCDIR}/config/etc/tc\" \"${SF_BASEDIR}/config/etc\""
  
  # Create Master-SEED
  if [[ -z $SF_SEED ]]; then
    if [[ -f "${SF_BASEDIR}/config/etc/seed/seed.txt" ]]; then
      SF_SEED="$(cat "${SF_BASEDIR}/config/etc/seed/seed.txt")"
    else
      [[ -d "${SF_BASEDIR}/config/etc/seed" ]] || SUDO_SF mkdir "${SF_BASEDIR}/config/etc/seed"
      SF_SEED="$(head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32)"
      SUDO_SF "echo \"${SF_SEED}\" >\"${SF_BASEDIR}/config/etc/seed/seed.txt\"" || ERREXIT
    fi
  fi

  # Setup /dev/shm/sf-u1001/run/log (in-memory /var/run...)
  if [[ -d /dev/shm ]]; then
    SF_SHMDIR="/dev/shm/sf-u${SF_HOST_USER_ID}"
  else
    SF_SHMDIR="/tmp/sf-u${SF_HOST_USER_ID}"
  fi

  # Create ./data or symlink correctly.
  [[ -n $SF_DATADIR ]] && {
    [[ ! -d "$SF_DATADIR" ]] && mkdir -p "$SF_DATADIR"
    [[ ! -d "${SF_BASEDIR}/data" ]] && ln -s "$SF_DATADIR" "${SF_BASEDIR}/data"
  }

  # Copy over sfbin
  [[ ! -d "${SF_BASEDIR}/sfbin" ]] && SUDO_SF "cp -r \"${SFI_SRCDIR}/sfbin\" \"${SF_BASEDIR}\""
}

# Add user
init_user

# Move SSHD out of the way if SF_SSH_PORT==22 (to port 64222)
init_host_sshd

init_basedir

# Install Docker and docker-cli
install_docker

# SSHD's login user (normally 'root' with uid 1000) needs to start docker instances
usermod -a -G docker "${SF_HOST_USER}"

# NOTE: Only needed if source is mounted into vmbox (for testing)
[[ "$(stat -c %G /segfault 2>/dev/null)" = "vboxsf" ]] && usermod -a -G vboxsf "${SF_HOST_USER}"

# SNAPSHOT #3 (2022-07-22)
# exit

# Create SSH-KEYS and directories.
[[ -d "${SF_BASEDIR}/config/etc/ssh" ]] || {
  IS_NEW_SSH_HOST_KEYS=1
  SUDO_SF "mkdir -p \"${SF_BASEDIR}/config/etc/ssh\" && ssh-keygen -A -f \"${SF_BASEDIR}\"/config"
}
[[ -f "${SF_BASEDIR}/config/etc/ssh/id_ed25519" ]] || {
  IS_NEW_SSH_LOGIN_KEYS=1
  SUDO_SF "ssh-keygen -q -t ed25519 -C \"\" -N \"\" -f \"${SF_BASEDIR}/config/etc/ssh/id_ed25519\""
}

init_config_run_sfbin

### Create guest, encfs and other docker images.
[[ -z $SF_NO_INTERNET ]] && { SUDO_SF "cd ${SFI_SRCDIR} && make" || exit; }

# SNAPSHOT #4 (2022-07-22)
# SNAPSHOT #4.1 (2022-07-23)
# exit

### Find out my own hostname unless SF_FQDN is set (before NordVPN is runnning)
[[ -z $SF_FQDN ]] && {
  # Find out my own hostname
  [[ -z $SF_NO_INTERNET ]] && {
    IP="$(curl ifconfig.me 2>/dev/null)"
    HOST="$(host "$IP")" && { HOST="$(echo "$HOST" | sed -E 's/.*name pointer (.*)\.$/\1/g')"; true; } || HOST="$(hostname -f)"
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
SF_NORDVPN_PRIVATE_KEY_ESC="${SF_NORDVPN_PRIVATE_KEY//\//\\/}"
SF_FQDN_ESC="${SF_FQDN//\//\\/}"
SF_SHMDIR_ESC="${SF_SHMDIR//\//\\/}"
# .env needs to be where the images are build (in the source directory)
ENV="${SFI_SRCDIR}/.env"
if [[ -e "${ENV}" ]]; then
  IS_USING_EXISTING_ENV_FILE=1
else
  SUDO_SF "cp \"${SFI_SRCDIR}/provision/env.example\" \"${ENV}\" && \
  sed -i 's/^SF_BASEDIR.*/SF_BASEDIR=${SF_BASEDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/.*SF_SHMDIR.*/SF_SHMDIR=${SF_SHMDIR_ESC}/' \"${ENV}\" && \
  sed -i 's/.*SF_FQDN.*/SF_FQDN=${SF_FQDN_ESC}/' \"${ENV}\"" || ERREXIT 120 failed
  [[ -n $SF_SSH_PORT ]] && { SUDO_SF "sed -i 's/.*SF_SSH_PORT.*/SF_SSH_PORT=${SF_SSH_PORT}/' \"${ENV}\"" || ERREXIT 121 failed; }
  [[ -n $SF_NORDVPN_PRIVATE_KEY ]] && { SUDO_SF "sed -i 's/.*SF_NORDVPN_PRIVATE_KEY.*/SF_NORDVPN_PRIVATE_KEY=${SF_NORDVPN_PRIVATE_KEY_ESC}/' \"${ENV}\"" || ERREXIT 121 failed; }
  [[ -n $SF_MAXOUT ]] && { SUDO_SF "sed -i 's/.*SF_MAXOUT.*/SF_MAXOUT=${SF_MAXOUT}/' \"${ENV}\"" || ERREXIT 121 failed; }
  [[ -n $SF_MAXIN ]] && { SUDO_SF "sed -i 's/.*SF_MAXIN.*/SF_MAXIN=${SF_MAXIN}/' \"${ENV}\"" || ERREXIT 121 failed; }
fi

(cd "${SFI_SRCDIR}" && \
  docker-compose pull && \
  docker-compose build -q && \
  docker network prune -f)
if docker ps | egrep "sf-host|sf-router" >/dev/null; then
  WARNMSG="A SEGFAULT is already running."
  IS_DOCKER_NEED_MANUAL_START=1
else
  docker container rm sf-host &>/dev/null
  (cd "${SFI_SRCDIR}" && SF_SEED="${SF_SEED}" docker-compose up --force-recreate -d) || { WARNMSG="Could not start docker-compose."; IS_DOCKER_NEED_MANUAL_START=1; }
fi

GS_SECRET=$(echo -n "GS-${SF_SEED}${SF_FQDN}" | sha512sum | base64 | tr -dc '[:alpha:]' | head -c 12)

echo -e "***${CG}SUCCESS${CN}***"
[[ -z $IS_USING_EXISTING_ENV_FILE ]] || WARN 4 "Using existing .env file (${ENV})"
[[ -z $IS_DOCKER_NEED_MANUAL_START ]] || {
  WARN 5 "${WARNMSG} Please run:"
  INFO "(cd \"${SFI_SRCDIR}\" && \\ \n\
    docker-compose down && docker network prune -f && docker container rm sf-host 2>/dev/null; \\ \n\
    SF_SEED=\"${SF_SEED}\" docker-compose up --force-recreate -d)"
}
[[ -z $SF_NORDVPN_PRIVATE_KEY ]] && {
  WARN 6 "NordVPN ${CR}DISABLED${CN}. Set SF_NORDVPN_PRIVATE_KEY= to enable."
  INFO "To retrieve the PRIVATE_KEY try: \n\
    ${CDC}docker run --rm --cap-add=NET_ADMIN -e USER=XXX -e PASS=YYY bubuntux/nordvpn:get_private_key${CN}"
}
[[ -n $IS_SSH_GOT_MOVED ]] && INFO "${CY}System's SSHD was in the way and got moved to ${SF_SSH_PORT_MASTER}${CN}"

INFO "Basedir             : ${CC}${SF_BASEDIR}${CN}"
INFO "SF_SEED             : ${CDY}${SF_SEED}${CN}"
INFO "Password            : ${CDY}${SF_USER_PASSWORD:-segfault}${CN}"

[[ -n $SF_SSH_PORT ]] && PORTSTR="-p${SF_SSH_PORT} "
INFO "SSH                 : ${CDC}ssh ${PORTSTR}${SF_USER:-root}@${SF_FQDN:-UNKNOWN}${CN}"
INFO "SSH (gsocket)       : ${CDC}gsocket -s ${GS_SECRET} ssh ${SF_USER:-root}@${SF_FQDN%.*}.gsocket${CN}"

[[ -z $IS_NEW_SSH_HOST_KEYS ]] &&  STR="existing" || STR="${CR}***NEW***${CN}"
INFO "SSH Host Keys       : $(cd "${SF_BASEDIR}/config" && md5sum etc/ssh/ssh_host_ed25519_key) (${STR})"
[[ -z $IS_NEW_SSH_LOGIN_KEYS ]] &&  STR="existing" || STR="${CR}***NEW***${CN}"
INFO "SSH Login Keys      : $(cd "${SF_BASEDIR}/config" && md5sum etc/ssh/id_ed25519) (${STR})"





