#! /bin/bash

CY="\033[1;33m" # yellow
CR="\033[1;31m" # red
CC="\033[1;36m" # cyan
CN="\033[0m"    # none

[[ -d /config ]] || {
	echo -e "${CR}Not found: /config${CN}
--> Try -v ~/segfault/config:ro -v ~/segfault/config/db:/config/db"

	sleep 5
	exit 255
} 

[[ -d /config/db ]] || {
	echo -e "${CR}Not found: /config/db${CN}
--> Try -v ~/segfault/config:ro -v ~/segfault/config/db:/config/db"

	sleep 5
	exit 255
} 

# This is the entry point for SF-HOST (e.g. host/Dockerfile)
# Fix ownership if mounted from within vbox
[[ -e /config/etc/ssh/ssh_host_rsa_key ]] || {
	echo -e "\
${CR}SSH Key not found in /config/etc/ssh/${CN}. You must create them first:
--> ${CC}mkdir -p ~/segfault/config/etc/ssh && ssh-keygen -A -f ~/segfault/config${CN}"

	sleep 5
	exit 255
}

[[ -e /config/etc/ssh/id_ed25519 ]] || {
	echo -e "\
${CR}SSH Login Key not found in /config/etc/ssh/id_ed25519${CN}. You must create them first:
--> ${CC}ssh-keygen -q -t ed25519 -C \"\" -N \"\" -f ~/segfault/config/etc/ssh/id_ed25519${CN}"

	sleep 5
	exit 255
}

# Copy login-key to fake root's home directory
[[ -e /home/root/.ssh/authorized_keys ]] || {
	[[ -d /home/root/.ssh ]] || { mkdir /home/root/.ssh; chown root:nobody /home/root/.ssh; }
	cp /config/etc/ssh/id_ed25519.pub /home/root/.ssh/authorized_keys
	chown root:nobody /home/root/.ssh/authorized_keys
}

# Make a copy so that sf-hosts's root(uid=1000) can access the file.
cp /config/etc/ssh/id_ed25519 /var/run/id_ed25519.luser
chmod 444 /var/run/id_ed25519.luser

# SSHD resets the environment variables. The environment variables relevant to the guest
# are stored in a file here and then read by `segfaultsh'.
# Edit 'segfaultsh' and add them to 'docker run --env' to pass any of these
# variables to the user's docker instance (sf-guest)
echo "LDNS=\"${LDNS}\"
LENCFS_SECDIR=\"${LENCFS_SECDIR}\"
LENCFS_RAWDIR=\"${LENCFS_RAWDIR}\"
SF_SRCDIR=\"${SF_SRCDIR}\"
LUSER=\"${LUSER}\"
SF_DEBUG=\"${SF_DEBUG}\"
SF_BASEDIR=\"${SF_BASEDIR}\"
SF_FQDN=\"${SF_FQDN}\"" >/var/run/lhost-config.txt

# The owner of the original socket is not known at 'docker build' time. Thus 
# we need to dynamically add it so that the shell started by SSHD can
# spwan ther SF-GUEST instance.
[[ ! -e /var/run/docker.sock ]] && { echo "Not found: /var/run/docker.sock"; echo "Try -v /var/run/docker.sock:/var/run/docker.sock"; exit 255; }
echo "docker:x:$(stat -c %g /var/run/docker.sock):${LUSER}" >>/etc/group && \
chmod 770 /var/run/docker.sock && \

# SSHD's user (normally "root" with uid 1000) needs write access to /config/db
# That directory is mounted from the outside and we have no clue what the
# group owner or permission is. Need to add our root(uid=1000) to that group:
dbgid="$(stat -c %g /config/db)"
[[ "$dbgid" -eq 0 ]] && {
	echo -e "${CY}WARNING:${CN} /config/db has group owner of 'root'.
--> Better try: ${CC}chgrp nogroup ~/segfault/config/db${CN}"
}
addgroup -g $(stat -c %g /config/db) sf-dbrw 2>/dev/null # Ignore if already exists.
addgroup root sf-dbrw 2>/dev/null # Ignore if already exists.
chmod g+wx /config/db || exit $?

# This will execute 'segfaultsh' on login
/usr/sbin/sshd -u0 -p 2222 -D
# /usr/sbin/sshd -u0 -p 2222

tail -f /dev/null

