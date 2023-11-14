#! /bin/bash

# Installs & Bootstraps 'Segfault Hosting Solution' onto a vanilla Linux Server.
#
# See https://www.thc.org/segfault/deploy to install with a single command.
#
# Environment variables:
#     SF_HOST_USER   - The user on the server under which 'segfault' is installed. (e.g. /home/ubuntu)
#     SF_NO_INTERNET - DEBUG: Runs script without Internet
#     SF_DEBUG=1     - Output DEBUG information
#     SF_DATADIR=    - Location of ./data (e.g. /sf/data)
#     SF_CONFDIR=    - Location of ./config (e.g. /sf/config)

SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
# shellcheck disable=SC1091
source "${0%/*}/system/funcs" || exit 255
NEED_ROOT

SUDO_SF()
{
  DEBUGF "${SF_HOST_USER} $*"
  sudo -u "${SF_HOST_USER}" bash -c "$*"
}

init_vars()
{
  if command -v apt-get >/dev/null; then
    source "${0%/*}/funcs_ubuntu.sh"
  elif command -v yum >/dev/null; then
    source "${0%/*}/funcs_al2.sh"
  else
    ERREXIT 255 "Unknown Linux flavor: No apt-get and no yum."
  fi

  # export DEBIAN_FRONTEND=noninteractive # Must e interactive so that we get warning if kernel got updated (needs reboot)
  [[ -z $SF_SEED ]] && ERREXIT 255 "SF_SEED= not set. Try \`export SF_SEED=\"\$(head -c 1024 /dev/urandom |base64| tr -dc '[:alpha:]' | head -c 32)\"\`"
  [[ -z $MAXMIND_KEY ]] && ERREXIT 255 "MAXMIND_KEY= not set. Try ${CDC}export MAXMIND_KEY=skip${CN} to disable. See https://support.maxmind.com/hc/en-us/articles/4407111582235-Generate-a-License-Key"
  [[ $MAXMIND_KEY == "skip" ]] && unset MAXMIND_KEY
}


init_user()
{
  # INIT: Find valid user to use for installation
  [[ -z $SF_HOST_USER ]] && {
    # EC2 default is 'ubuntu' or 'ec2-user'. Fall-back to 'sf-user' otherwise.
    if id -u ubuntu &>/dev/null; then
      SF_HOST_USER="ubuntu"
    elif id -u ec2-user &>/dev/null; then
      SF_HOST_USER="ec2-user"
    else
      SF_HOST_USER="sf-user"
    fi

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

  chown -R "${SF_HOST_USER}" "${SFI_SRCDIR:?}"
}

init_host_sshd()
{
  local port

  # Configure SSHD
  [[ -f /etc/ssh/sshd_config ]] || return

  port=${SF_SSH_PORT:-22}
  : "${SF_SSH_PORT_MASTER:=64222}"

  # Move original SSH server out of the way...
  [[ "${port}" -eq 22 ]] && grep "Port 22" /etc/ssh/sshd_config >/dev/null && {
    sed -i -E "s/#Port ${port}/Port ${SF_SSH_PORT_MASTER}/g" /etc/ssh/sshd_config
    DEBUGF "Restarting SSHD on port ${SF_SSH_PORT_MASTER}"
    service sshd restart
    IS_SSH_GOT_MOVED=1
  }
}

# sf_linkdir [dst] [src]
sf_linkdir()
{
  local dst
  local src
  dst="${1:?}"
  src="${2:?}"

  # If dst does not exit then ignore
  [[ ! -d "${dst}" ]] && return
  # If both directories are already the same
  [[ "${src}" -ef "${dst}" ]] && return

  [[ -d "${src}" ]] && { rmdir "${src}" || ERREXIT 254 "Cant link ${src} to ${dst} because ${src} is not empty."; }
  ln -s "${dst}" "${src}" || ERREXIT
}

# Setup BASEDIR and create links to /sf hirachy (if it exists).
init_basedir()
{
  # INIT: Find good location for dynamic configuration
  [[ -z $SF_BASEDIR ]] && {
    SUDO_SF "mkdir -p ~/segfault"
    SF_BASEDIR="$(cd "/home/${SF_HOST_USER}/segfault" || exit; pwd)"
  }
  DEBUGF "SF_BASEDIR=${SF_BASEDIR}"
}

# Try to merge new config into old directory and yield if
# we did not overwrite old config
mergedir()
{
  local src
  local dst


  [[ "$SFI_SRCDIR" == "$SF_BASEDIR" ]] && return

  src="$1"
  dst="$(dirname "$src")"

  # create ./config/etc if it does not exist yet.
  [[ ! -d "${SF_BASEDIR}/${dst}" ]] && mkdir -p "${SF_BASEDIR}/${dst}"

  DEBUGF "Merge $src $dst"
  if [[ -d "${SF_BASEDIR}/${src}" ]]; then
    CONFLICT+=("${src}")
    return 1
  fi
  cp -r "${SFI_SRCDIR}/${src}" "${SF_BASEDIR}/${dst}" || ERREXIT
  
  return 0
}

init_config_run()
{
  : "${SF_DATADIR:=${SF_BASEDIR}/data}"
  : "${SF_CONFDIR:=${SF_BASEDIR}/config}"

  # Create ./data or symlink correctly.
  [[ ! -d "${SF_DATADIR}" ]] && mkdir -p "${SF_DATADIR}"
  [[ ! -d "${SF_DATADIR}/share" ]] && mkdir -p "${SF_DATADIR}/share"
  [[ ! "${SF_BASEDIR}/data" -ef "${SF_DATADIR}" ]] && ln -s "${SF_DATADIR}" "${SF_BASEDIR}/data"

  [[ ! -d "${SF_CONFDIR}" ]] && mkdir -p "${SF_CONFDIR}"
  [[ ! "${SF_BASEDIR}/config" -ef "${SF_CONFDIR}" ]] && {
    [[ -d "${SF_BASEDIR}/config" ]] && mv "${SF_BASEDIR}/config" "${SF_BASEDIR}/config.orig-$(date +%s)"
    ln -s "${SF_CONFDIR}" "${SF_BASEDIR}/config"
  }

  mergedir "config/etc/sf" && IS_ETCSF_UPDATE=1
  mergedir "config/etc/nginx"
  mergedir "config/etc/redis"
  mergedir "config/etc/resolv.conf"

  [[ ! -f "${SF_DATADIR}/share/GeoLite2-City.mmdb" ]] && [[ -n "${MAXMIND_KEY}" ]] && curl 'https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key='"${MAXMIND_KEY}"'&suffix=tar.gz' | tar xfvz  - --strip-components=1  --no-anchored -C "${SF_DATADIR}/share/" 'GeoLite2-City.mmdb'
  [[ ! -f "${SF_DATADIR}/share/tor-exit-nodes.txt" ]] && curl 'https://www.dan.me.uk/torlist/?exit' >"${SF_DATADIR}/share/tor-exit-nodes.txt"

  # Setup /dev/shm/sf/run/log (in-memory /var/run...)
  if [[ -d /dev/shm ]]; then
    SF_SHMDIR="/dev/shm/sf"
  else
    SF_SHMDIR="/tmp/sf"
  fi

  # Copy over sfbin
  [[ ! "$SFI_SRCDIR" -ef "$SF_BASEDIR" ]] && [[ -d "${SF_BASEDIR}/sfbin" ]] && rm -rf "${SF_BASEDIR}/sfbin"
  mergedir "sfbin"

  grep -F .bashrc /root/.bash_profile >/dev/null || echo ". .bashrc" >>/root/.bash_profile
  grep -F funcs_admin.sh /root/.bash_profile >/dev/null || echo ". ${SF_BASEDIR}/sfbin/funcs_admin.sh" >>/root/.bash_profile
  # Configure BFQ module
  grep ^bfq /etc/modules &>/dev/null || echo "bfq" >>/etc/modules
  modprobe bfq || {
    "${PKG_INSTALL[@]}" linux-modules-extra-aws
    # Does this need `GRUB_CMDLINE_LINUX="scsi_mod.use_blk_mq=1"` in /etc/default/grub on Ubuntu?
    # It could be that the kernel got upgraded.
    modprobe bfq || ERREXIT 255 "Cant load BFQ module. Please install the BFQ kernel module. Reboot may also work."
  }
  "${PKG_INSTALL[@]}" jq
}

docker_fixdir()
{
  [[ ! -d /sf ]] && return
  [[ ! -d /sf/docker ]] && mkdir /sf/docker
  [[ "/sf/docker" -ef "/var/lib/docker" ]] && return

  # Stop docker. Should not be running but who knows..
  docker ps >/dev/null && {
    WARN 1 "Docker already running. Stopping it for now..."
    systemctl stop docker
    systemctl stop docker.socket
  }

  # Delete if there is any old data in there...
  rm -rf /sf/docker/* &>/dev/null

  mv /var/lib/docker/* /sf/docker/ || return
  rmdir /var/lib/docker || return
  ln -s /sf/docker /var/lib/docker || return
}

# Install $1 from provision/system to ${2}/${1}
xinstall()
{
  local fn
  local dir
  fn="$1"
  dir="$2"

  [[ -f "${dir}/${fn}" ]] && { CONFLICT+=("${dir}/${fn}"); return 1; }

  cp -a "${SFI_SRCDIR}/provision/system/${fn}" "${dir}" || ERREXIT 233
}

docker_config()
{
  xinstall sf.slice /etc/systemd/system
  xinstall sf-guest.slice /etc/systemd/system
  sed 's/^Restart=always.*$/Restart=on-failure/' -i /lib/systemd/system/docker.service
  sed 's/^OOMScoreAdjust=.*$/OOMScoreAdjust=-1000/' -i /lib/systemd/system/docker.service
  sed 's/.*DefaultCPUAccounting=no.*/DefaultCPUAccounting=yes/' -i /etc/systemd/system.conf
  sed 's/.*DefaultIOAccounting=no.*/DefaultIOAccounting=yes/' -i /etc/systemd/system.conf
  # systemctl daemon-reload
  systemctl daemon-reexec # reload system.conf
  systemctl start sf.slice
  systemctl start sf-guest.slice
}

docker_start()
{
  docker ps >/dev/null && return
  systemctl start docker
}

DEBUGF "Initializing variables..."
init_vars

DEBUGF "Updating..."
"${PKG_UPDATE[@]}"

DEBUGF "Adding user..."
# Add user
init_user

# Move SSHD out of the way if SF_SSH_PORT==22 (to port 64222)
init_host_sshd

init_basedir

# Install Docker & software
install_sw

docker_fixdir
docker_config
docker_start

# Install QEMU and register binfmt
"${PKG_INSTALL[@]}" qemu binfmt-support qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# SSHD's login user (normally 'root' with uid 1000) needs to start docker instances
usermod -a -G docker "${SF_HOST_USER}"

# Free some space
pkg_clean
command -v snap >/dev/null && snap list --all | awk '/disabled/{print $1, $3}' | while read pkg revision; do
    snap remove "$pkg" --revision="$revision"
done
if grep "^#SystemMaxUse=$" /etc/systemd/journald.conf >/dev/null; then
  sed 's/#SystemMaxFileSize.*/SystemMaxFileSize=50M/' -i /etc/systemd/journald.conf
  sed 's/#SystemMaxUse.*/SystemMaxUse=10M/' -i /etc/systemd/journald.conf
  systemctl restart systemd-journald
fi
journalctl --vacuum-size=20M
journalctl --vacuum-time=10d

sed 's/rotate 4/rotate 2/' -i /etc/logrotate.conf
sed 's/rotate 4/rotate 2\n\tsize 64M\n\tminsize 128k/' -i /etc/logrotate.d/rsyslog

# NOTE: Only needed if source is mounted into vmbox (for testing)
[[ "$(stat -c %G /research/segfault 2>/dev/null)" == "vboxsf" ]] && usermod -a -G vboxsf "${SF_HOST_USER}"

# SNAPSHOT #3 (2022-07-22)
# exit
"${PKG_UPDATE[@]}"
init_config_run

### Create guest, encfs and other docker images.
[[ -z $SF_NO_INTERNET ]] && { cd "${SFI_SRCDIR}" && make || exit; }

# Only needed if installed via 
[[ "$(stat -c %G /research/segfault 2>/dev/null)" == "vboxsf" ]] && {
  chmod 644 "${SF_CONFDIR}/etc/redis/redis.conf"
  chmod 755 "${SF_BASEDIR}/sfbin"
  chmod 644 "${SF_BASEDIR}/sfbin/funcs*"
}
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
# .env needs to be where the images are build (in the source directory)
ENV="${SF_CONFDIR}/.env"
[[ ! -e "${SFI_SRCDIR}/.env" ]] && ln -sf "${ENV}" "${SFI_SRCDIR}/.env"
if [[ -e "${ENV}" ]]; then
  IS_USING_EXISTING_ENV_FILE=1
  CONFLICT+=("${ENV}");
else
  cp "${SFI_SRCDIR}/provision/env.example" "${ENV}" || ERREXIT 122 failed
  sed "s/^SF_BASEDIR.*/SF_BASEDIR=${SF_BASEDIR//\//\\/}/" -i "${ENV}" || ERREXIT 132 failed
  sed "s/.*SF_SHMDIR.*/SF_SHMDIR=${SF_SHMDIR//\//\\/}/" -i "${ENV}" || ERREXIT 133 failed
  sed "s/.*SF_FQDN.*/SF_FQDN=${SF_FQDN//\//\\/}/" -i "${ENV}" || ERREXIT 120 failed
  [[ -n $SF_SSH_PORT ]] && { sed "s/.*SF_SSH_PORT.*/SF_SSH_PORT=${SF_SSH_PORT}/" -i "${ENV}" || ERREXIT 121 failed; }
  [[ -n $SF_NORDVPN_PRIVATE_KEY ]] && { sed "s/.*SF_NORDVPN_PRIVATE_KEY.*/SF_NORDVPN_PRIVATE_KEY=${SF_NORDVPN_PRIVATE_KEY//\//\\/}/" -i "${ENV}" || ERREXIT 121 failed; }
  [[ -n $SF_MULLVAD_CONFIG ]] && { sed "s/.*SF_MULLVAD_CONFIG.*/SF_MULLVAD_CONFIG=${SF_MULLVAD_CONFIG//\//\\/}/" -i "${ENV}" || ERREXIT 121 failed; }
  [[ -n $SF_CRYPTOSTORM_CONFIG ]] && { sed "s/.*SF_CRYPTOSTORM_CONFIG.*/SF_CRYPTOSTORM_CONFIG=${SF_CRYPTOSTORM_CONFIG//\//\\/}/" -i "${ENV}" || ERREXIT 121 failed; }
fi

# Copy all relevant env variables into config/etc/sf.conf
[[ -n $IS_ETCSF_UPDATE ]] && {
  set | grep ^SF_ | while read x; do
    name="${x%%=*}"
    val="$(eval echo \$"$name")"
    sed -i -E "s/^#${name}=.*/${name}=${val//\//\\/}/" "${SF_BASEDIR}/config/etc/sf/sf.conf"
  done
}

(cd "${SFI_SRCDIR}" && \
  sfbin/sf build -q && \
  docker network prune -f) || ERREXIT

GS_SECRET=$(echo -n "GS-${SF_SEED}${SF_FQDN}" | sha512sum | base64 | tr -dc '[:alpha:]' | head -c 12)

echo -e "***${CG}SUCCESS${CN}***"
[[ -z $IS_USING_EXISTING_ENV_FILE ]] || WARN 4 "Using existing .env file (${ENV})"
# INFO "To Start       :(cd \"${SFI_SRCDIR}\" && "'\\\n'"\
#   docker-compose down; docker stop \$(docker ps -q --filter name='^(lg-|encfs-)'); "'\\\n'"\
#   docker network prune -f; docker container rm sf-host 2>/dev/null; "'\\\n'"\
#   SF_SEED=\"${SF_SEED}\" sfbin/sf up --force-recreate -d)"

[[ -z $SF_NORDVPN_PRIVATE_KEY ]] && {
  WARN 6 "NordVPN ${CR}DISABLED${CN}. Set SF_NORDVPN_PRIVATE_KEY= to enable."
  INFO "To retrieve the PRIVATE_KEY try: \n\
    ${CDC}docker run --rm --cap-add=NET_ADMIN -e USER=XXX -e PASS=YYY bubuntux/nordvpn:get_private_key${CN}"
}
[[ -z $SF_MULLVAD_CONFIG ]] && WARN 6 "MullVad ${CR}DISABLED${CN}. Set SF_MULLVAD_CONFIG= to enable."
[[ -z $SF_CRYPTOSTORM_CONFIG ]] && WARN 6 "CrytoStorm ${CR}DISABLED${CN}. Set SF_CRYPTOSTORM_CONFIG= to enable"

[[ -n $IS_SSH_GOT_MOVED ]] && INFO "${CY}System's SSHD was in the way and got moved to ${SF_SSH_PORT_MASTER}${CN}"

INFO "Basedir             : ${CC}${SF_BASEDIR}${CN}"
INFO "SF_SEED             : ${CDY}${SF_SEED}${CN}"
INFO "Password            : ${CDY}${SF_USER_PASSWORD:-segfault}${CN}"
INFO "To Start            : ${CDY}SF_SEED='$SF_SEED' sfbin/sf up --force-recreate${CN}"

[[ -n $SF_SSH_PORT ]] && PORTSTR="-p${SF_SSH_PORT} "
INFO "SSH                 : ${CDC}ssh ${PORTSTR}${SF_USER:-root}@${SF_FQDN:-UNKNOWN}${CN}"
INFO "SSH (gsocket)       : ${CDC}gsocket -s ${GS_SECRET} ssh ${SF_USER:-root}@${SF_FQDN%.*}.gsocket${CN}"

[[ ${#CONFLICT[@]} -gt 0 ]] && {
  WARN 7 "Not updating these:"
  for x in "${CONFLICT[@]}"; do
    INFO "${x}"
  done
}

