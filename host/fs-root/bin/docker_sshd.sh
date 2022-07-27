#! /bin/bash

CY="\033[1;33m" # yellow
CR="\033[1;31m" # red
CC="\033[1;36m" # cyan
CN="\033[0m"    # none


ERREXIT()
{
	local s
	local code
	code="$1"
	s="$2"

	shift 2

	echo -e >&2 "$*"

	sleep "$s"
	exit "$code"
}

[[ -z $SF_BASEDIR ]] && {
	# FATAL: Repeat loop until user fixes this bug.
	while :; do
		echo -e >&2 "${CR}SF_BASEDIR= not set. Try \`SF_BASEDIR=\$(pwd) docker-compose up\`.${CN}"
		sleep 5
	done
}

[[ -d /config ]] || ERREXIT 255 5 "${CR}Not found: /config${CN}. Try -v \${SF_BASEDIR}/config:/config,ro -v \${SF_BASEDIR}/config/db:/config/db"

[[ -d /config/db ]] || ERREXIT 255 5 "${CR}Not found: /config/db${CN}. Try -v \${SF_BASEDIR}/config:/config,ro -v \${SF_BASEDIR}/config/db:/config/db"

# This is the entry point for SF-HOST (e.g. host/Dockerfile)
# Fix ownership if mounted from within vbox
[[ -e /config/etc/ssh/ssh_host_rsa_key ]] || {
	[[ ! -d "/config/etc/ssh" ]] && { mkdir -p "/config/etc/ssh" || ERREXIT 255 5; }

	ssh-keygen -A -f "/config" 2>&1 # Always return 0, even on failure.
	[[ ! -f "/config/etc/ssh/ssh_host_rsa_key" ]] && ERREXIT 255 5
}

[[ -e /config/etc/ssh/id_ed25519 ]] || {
	ssh-keygen -q -t ed25519 -C "" -N "" -f /config/etc/ssh/id_ed25519 2>&1
	[[ ! -f "/config/etc/ssh/id_ed25519" ]] && ERREXIT 255 5
}

# Copy login-key to fake root's home directory
[[ -e /home/"${SF_USER}"/.ssh/authorized_keys ]] || {
	[[ -d /home/"${SF_USER}"/.ssh ]] || { mkdir /home/"${SF_USER}"/.ssh; chown "${SF_USER}":nobody /home/"${SF_USER}"/.ssh; }
	cp /config/etc/ssh/id_ed25519.pub /home/"${SF_USER}"/.ssh/authorized_keys
	# Copy of private key so that segfaultsh (in uid=1000 context)
	# can display the private key for future logins.
	cp /config/etc/ssh/id_ed25519 /home/"${SF_USER}"/.ssh/
	chown "${SF_USER}":nobody /home/"${SF_USER}"/.ssh/authorized_keys /home/"${SF_USER}"/.ssh/id_ed25519
}

# SSHD resets the environment variables. The environment variables relevant to the guest
# are stored in a file here and then read by `segfaultsh'.
# Edit 'segfaultsh' and add them to 'docker run --env' to pass any of these
# variables to the user's docker instance (sf-guest)
echo "SF_DNS=\"${SF_DNS}\"
SF_ENCFS_SECDIR=\"${SF_ENCFS_SECDIR}\"
SF_USER=\"${SF_USER}\"
SF_DEBUG=\"${SF_DEBUG}\"
SF_BASEDIR=\"${SF_BASEDIR}\"
SF_RUNDIR=\"${SF_RUNDIR}\"
SF_FQDN=\"${SF_FQDN}\"" >/var/run/lhost-config.txt

# The owner of the original socket is not known at 'docker build' time. Thus 
# we need to dynamically add it so that the shell started by SSHD can
# spwan ther SF-GUEST instance.
[[ ! -e /var/run/docker.sock ]] && { echo "Not found: /var/run/docker.sock"; echo "Try -v /var/run/docker.sock:/var/run/docker.sock"; exit 255; }
echo "docker:x:$(stat -c %g /var/run/docker.sock):${SF_USER}" >>/etc/group && \
chmod 770 /var/run/docker.sock && \

# SSHD's user (normally "root" with uid 1000) needs write access to /config/db
# That directory is mounted from the outside and we have no clue what the
# group owner or permission is. Need to add our root(uid=1000) to that group.
# However, we dont like this to be group=0 (root) so we force it to nogroup
# if it is root.
[[ "$(stat -c %g /config/db)" -eq 0 ]] && chgrp nogroup /config/db # Change root -> nogroup
addgroup -g "$(stat -c %g /config/db)" sf-dbrw 2>/dev/null # Ignore if already exists.
addgroup "${SF_USER}" "$(stat -c %G /config/db)" 2>/dev/null # Ignore if already exists.
chmod g+wx /config/db || exit $?

# This will execute 'segfaultsh' on root-login (uid=1000)
/usr/sbin/sshd -u0 -p 2222 -D
# /usr/sbin/sshd -u0 -p 2222

tail -f /dev/null

