#! /bin/bash

# CY="\e[1;33m" # yellow
CR="\e[1;31m" # red
# CC="\e[1;36m" # cyan
CN="\e[0m"    # none


SLEEPEXIT()
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

create_load_seed()
{
	[[ -n $SF_SEED ]] && return
	[[ ! -f "/config/etc/seed/seed.txt" ]] && {
		head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32 >/config/etc/seed/seed.txt || { echo >&2 "Can't create \${SF_BASEDIR}/config/etc/seed/seed.txt"; exit 255; }
	}
	SF_SEED="$(cat /config/etc/seed/seed.txt)"
	[[ -z $SF_SEED ]] && SLEEPEXIT 254 5 "Failed to generated SF_SEED="
}

setup_sshd()
{
	# Default is for user to use 'ssh root@segfault.net' but this can be changed
	# in .env to any other user name. In case it is 'root' then we need to move
	# the true root out of the way for the docker-sshd to work.
	tail -n1 /etc/passwd | grep ^"${SF_USER}" && { echo -e >&2 "WARNING: This should not happen"; tail -n4 /etc/passwd /etc/shadow; sleep 5; return; }

	if [[ "$SF_USER" = "root" ]]; then
		# rename root user
		sed -i 's/^root/toor/' /etc/passwd
		sed -i 's/^root/toor/' /etc/shadow
	fi

	adduser -D "${SF_USER}" -G nobody -s /bin/segfaultsh && \
	echo "${SF_USER}:${SF_USER_PASSWORD}" | chpasswd
}

[[ -z $SF_BASEDIR ]] && {
	# FATAL: Repeat loop until user fixes this bug.
	while :; do
		echo -e >&2 "${CR}SF_BASEDIR= not set. Try \`SF_BASEDIR=\$(pwd) docker-compose up\`.${CN}"
		sleep 5
	done
}

[[ ! -d /config ]] && SLEEPEXIT 255 5 "${CR}Not found: /config/db${CN}. Try -v \${SF_BASEDIR}/config:/config"

[[ ! -d /config/db ]] && { mkdir /config/db || SLEEPEXIT 255 5 "${CR}Cant create /config/db${CN}"; }

# Wait for systemwide encryption to be available.
# Note: Do not need to wait for /everyone because no other service
# depends on it and by the time a user loggs in it's either ready (and mounted)
# or wont get mounted to user.
/sf/bin/wait_semaphore.sh /sec/www-root/.IS-ENCRYPTED bash -c exit || exit 123

create_load_seed

setup_sshd

ip route del default
ip route add default via 172.22.0.254

# This is the entry point for SF-HOST (e.g. host/Dockerfile)
# Fix ownership if mounted from within vbox
[[ -e /config/etc/ssh/ssh_host_rsa_key ]] || {
	[[ ! -d "/config/etc/ssh" ]] && { mkdir -p "/config/etc/ssh" || SLEEPEXIT 255 5; }

	ssh-keygen -A -f "/config" 2>&1 # Always return 0, even on failure.
	[[ ! -f "/config/etc/ssh/ssh_host_rsa_key" ]] && SLEEPEXIT 255 5
}

[[ -e /config/etc/ssh/id_ed25519 ]] || {
	ssh-keygen -q -t ed25519 -C "" -N "" -f /config/etc/ssh/id_ed25519 2>&1
	[[ ! -f "/config/etc/ssh/id_ed25519" ]] && SLEEPEXIT 255 5
}

chmod 644 /config/etc/ssh/id_ed25519
# Copy login-key to fake root's home directory
[[ -e /home/"${SF_USER}"/.ssh/authorized_keys ]] || {
	[[ -d /home/"${SF_USER}"/.ssh ]] || { mkdir /home/"${SF_USER}"/.ssh; chown "${SF_USER}":nobody /home/"${SF_USER}"/.ssh; }
	cp /config/etc/ssh/id_ed25519.pub /home/"${SF_USER}"/.ssh/authorized_keys
	# Copy of private key so that segfaultsh (in uid=1000 context)
	# can display the private key for future logins.
	cp /config/etc/ssh/id_ed25519 /home/"${SF_USER}"/.ssh/
	chown "${SF_USER}":nobody /home/"${SF_USER}"/.ssh/authorized_keys /home/"${SF_USER}"/.ssh/id_ed25519
}

SF_CFG_GUEST_DIR="/config/guest"
[[ ! -d "${SF_CFG_GUEST_DIR}" ]] && SLEEPEXIT 255 3 "Not found: ${SF_CFG_GUEST_DIR}"
[[ ! -f "${SF_CFG_GUEST_DIR}/id_ed25519" ]] && cp "/config/etc/ssh/id_ed25519" "${SF_CFG_GUEST_DIR}/id_ed25519"

# SSHD resets the environment variables. The environment variables relevant to the guest
# are stored in a file here and then read by `segfaultsh'.
# Edit 'segfaultsh' and add them to 'docker run --env' to pass any of these
# variables to the user's docker instance (sf-guest)
echo "SF_DNS=\"${SF_DNS}\"
SF_TOR=\"${SF_TOR}\"
SF_SEED=\"${SF_SEED}\"
SF_USER=\"${SF_USER}\"
SF_DEBUG=\"${SF_DEBUG}\"
SF_BASEDIR=\"${SF_BASEDIR}\"
SF_SHMDIR=\"${SF_SHMDIR}\"
SF_FQDN=\"${SF_FQDN}\"" >/dev/shm/env.txt

# The owner of the original socket is not known at 'docker build' time. Thus 
# we need to dynamically add it so that the shell started by SSHD can
# spwan ther SF-GUEST instance.
[[ ! -e /var/run/docker.sock ]] && { echo "Not found: /var/run/docker.sock"; echo "Try -v /var/run/docker.sock:/var/run/docker.sock"; exit 255; }
echo "docker:x:$(stat -c %g /var/run/docker.sock):${SF_USER}" >>/etc/group && \
chmod 770 /var/run/docker.sock && \

# SSHD's user (normally "root" with uid 1000) needs write access to /config/db
# That directory is mounted from the outside and we have no clue what the
# group owner or permission is. Need to add our root(uid=1000) to that group.
# However, we dont like this to be group=0 (root) and if it is then we force it
# to nogroup.
[[ "$(stat -c %g /config/db)" -eq 0 ]] && chgrp nogroup /config/db # Change root -> nogroup
addgroup -g "$(stat -c %g /config/db)" sf-dbrw 2>/dev/null # Ignore if already exists.
addgroup "${SF_USER}" "$(stat -c %G /config/db)" 2>/dev/null # Ignore if already exists.
chmod g+wx /config/db || exit $?

# This will execute 'segfaultsh' on root-login (uid=1000)
exec 0<&- # Close STDIN
exec /usr/sbin/sshd -u0 -D
### NOT REACHED
exit 255
