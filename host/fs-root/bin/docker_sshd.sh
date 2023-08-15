#! /bin/bash

source /sf/bin/funcs_redis.sh

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

setup_sshd()
{
	# Default is for user to use 'ssh root@segfault.net' but this can be changed
	# in .env to any other user name. In case it is 'root' then we need to move
	# the true root out of the way for the docker-sshd to work.\

	# Check if passwd has already been modified
	tail -n1 /etc/passwd | grep ^secret >/dev/null && return

	if [[ "$SF_USER" == "root" ]]; then
		# rename root user
		sed -i 's/^root/toor/' /etc/passwd
		sed -i 's/^root/toor/' /etc/shadow
		sed -i 's/root/toor/g' /etc/group  # All occurances
	fi

	# The uid/gid must match the 'sleep' process in guest's container
	# so that sshd can be moved (setns()) to the guest's network namespace.
	addgroup -g 1000 user && \
	adduser -D "${SF_USER}" -G user -s /bin/segfaultsh && \
	echo "${SF_USER}:${SF_USER_PASSWORD}" | chpasswd || return

	echo 'webshell:x:1000:1000:SF webshell,,,:/home/webshell:/bin/webshellsh' >>/etc/passwd && \
	addgroup webshell user && \
	mkdir -p /home/webshell/.ssh && \
	chmod 700 /home/webshell/.ssh && \
	chown -R webshell:user /home/webshell || return

	echo "secret:x:1000:1000:SF asksec,,,:/home/${SF_USER}:/bin/asksecsh" >>/etc/passwd && \
	echo "secret:*::0:::::" >>/etc/shadow && \
	echo "secret:${SF_USER_PASSWORD}" | chpasswd || return
}

vboxfix()
{
	local fn
	local gid
	fn="$1"

	gid=$(stat -c %g "$fn")
	# Return if owned by root. Not mounted via vbox (debugging)
	[[ $gid -eq 0 ]] && return
	addgroup -g "$gid" vboxsf 2>/dev/null # This might fail.
	addgroup "${SF_USER}" "$(stat -c %G "$fn")" 2>/dev/null 
}

[[ -z $SF_BASEDIR ]] && {
	# FATAL: Repeat loop until user fixes this bug.
	while :; do
		echo -e >&2 "${CR}SF_BASEDIR= not set. Try \`SF_BASEDIR=\$(pwd) docker-compose up\`.${CN}"
		sleep 5
	done
}

SF_CFG_HOST_DIR="/config/host"
SF_CFG_GUEST_DIR="/config/guest"
[[ ! -d "${SF_CFG_HOST_DIR}" ]] && SLEEPEXIT 255 3 "Not found: ${SF_CFG_HOST_DIR}"
[[ ! -d "${SF_CFG_GUEST_DIR}" ]] && SLEEPEXIT 255 3 "Not found: ${SF_CFG_GUEST_DIR}"

[[ ! -d "${SF_CFG_HOST_DIR}" ]] && SLEEPEXIT 255 5 "${CR}Not found: ${SF_CFG_HOST_DIR}/db${CN}. Try -v \${SF_BASEDIR}/config:${SF_CFG_HOST_DIR}"
[[ ! -d "${SF_CFG_HOST_DIR}/db" ]] && { mkdir "${SF_CFG_HOST_DIR}/db" || SLEEPEXIT 255 5 "${CR}Cant create ${SF_CFG_HOST_DIR}/db${CN}"; }
[[ ! -d "${SF_CFG_HOST_DIR}/db/user" ]] && { mkdir "${SF_CFG_HOST_DIR}/db/user" || SLEEPEXIT 255 5 "${CR}Cant create ${SF_CFG_HOST_DIR}/db/user${CN}"; }
[[ ! -d "${SF_CFG_HOST_DIR}/db/banned" ]] && { mkdir "${SF_CFG_HOST_DIR}/db/banned" || SLEEPEXIT 255 5 "${CR}Cant create ${SF_CFG_HOST_DIR}/db/banned${CN}"; }
[[ ! -d "${SF_CFG_HOST_DIR}/db/hn" ]] && { mkdir "${SF_CFG_HOST_DIR}/db/hn" || SLEEPEXIT 255 5 "${CR}Cant create ${SF_CFG_HOST_DIR}/db/hn${CN}"; }
chown 1000:1000 "${SF_CFG_HOST_DIR}/db/hn"

SF_RUN_DIR="/sf/run"

mk_userdir()
{
	local fn
	fn="$1"

	[[ -d "${fn}" ]] && rm -rf "${fn:?}"
	mkdir -p "${fn}"
	chown 1000 "${fn}" || SLEEPEXIT 255 5 "${CR}Not found: ${fn}${CN}"
}

mk_userdir "${SF_RUN_DIR}/pids"
mk_userdir "${SF_RUN_DIR}/ips"

[[ ! -d "${SF_RUN_DIR}/logs" ]] && mkdir -p "${SF_RUN_DIR}/logs"
chown 1000 "${SF_RUN_DIR}/logs"
chmod 777 "/sf/run/redis/sock/redis.sock"

# Wait for systemwide encryption to be available.
# Note: Do not need to wait for /everyone because no other service
# depends on it and by the time a user loggs in it's either ready (and mounted)
# or wont get mounted to user.
/sf/bin/wait_semaphore.sh /sec/www-root/.IS-ENCRYPTED bash -c exit || exit 123

setup_sshd || exit

ip route del default
ip route add default via 172.22.0.254

# This is the entry point for SF-HOST (e.g. host/Dockerfile)
# Fix ownership if mounted from within vbox
[[ ! -e "${SF_CFG_HOST_DIR}/etc/ssh/ssh_host_rsa_key" ]] && {
	[[ ! -d "${SF_CFG_HOST_DIR}/etc/ssh" ]] && { mkdir -p "${SF_CFG_HOST_DIR}/etc/ssh" || SLEEPEXIT 255 5; }

	ssh-keygen -A -f "${SF_CFG_HOST_DIR}" 2>&1 # Always return 0, even on failure.
	[[ ! -f "${SF_CFG_HOST_DIR}/etc/ssh/ssh_host_rsa_key" ]] && SLEEPEXIT 255 5
}

mk_userkey()
{
	local fn
	local name
	name="$1"
	fn="id_ed25519"
	[[ -n $name ]] && fn="id_ed25519-${name}"

	[[ ! -e "${SF_CFG_HOST_DIR}/etc/ssh/${fn}" ]] && {
		ssh-keygen -q -t ed25519 -C "$name" -N "" -f "${SF_CFG_HOST_DIR}/etc/ssh/${fn}" 2>&1
		[[ ! -f "${SF_CFG_HOST_DIR}/etc/ssh/${fn}" ]] && SLEEPEXIT 255 5
	}
}

mk_userkey ""
mk_userkey "webshell"

chmod 644 "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519"
# Copy login-key to fake root's home directory
[[ ! -e /home/"${SF_USER}"/.ssh/authorized_keys ]] && {
	[[ -d "/home/${SF_USER}/.ssh" ]] || { mkdir "/home/${SF_USER}/.ssh"; chown "${SF_USER}":user "/home/${SF_USER}/.ssh"; }
	cp "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519.pub" "/home/${SF_USER}/.ssh/authorized_keys"
	# Copy of private key so that segfaultsh (in uid=1000 context)
	# can display the private key for future logins.
	cp "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519" "/home/${SF_USER}/.ssh/"
	chown "${SF_USER}":user "/home/${SF_USER}/.ssh/authorized_keys" "/home/${SF_USER}/.ssh/id_ed25519"
}

[[ ! -e /home/webshell/.ssh/authorized_keys ]] && {
	cp "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519-webshell.pub" "/home/webshell/.ssh/authorized_keys"
	chown webshell:user "/home/webshell/.ssh/authorized_keys"
}

# Always copy as it may have gotten updated:
cp "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519" "${SF_CFG_GUEST_DIR}/id_ed25519"
# [[ ! -f "${SF_CFG_GUEST_DIR}/id_ed25519" ]] && cp "${SF_CFG_HOST_DIR}/etc/ssh/id_ed25519" "${SF_CFG_GUEST_DIR}/id_ed25519"

# Create semaphore (buckets)
i=0
while [[ $i -lt $SF_HM_SIZE_LG ]]; do
	echo -e "DEL 'sema:lg-$i'\nRPUSH 'sema:lg-$i' 1" | red
	((i++))
done

# LXCFS creates different directories depending on the version.
[[ -d /var/lib/lxcfs/proc ]] && {
	unset str
	for fn in $(cd /var/lib/lxcfs; find proc -type f 2>/dev/null; find sys -type f 2>/dev/null); do
		str+="'-v' '/var/lib/lxcfs/${fn}:/$fn:ro' "
	done
	LXCFS_STR=$str
}

# SSHD resets the environment variables. The environment variables relevant to the guest
# are stored in a file here and then read by `segfaultsh'.
# Edit 'segfaultsh' and add them to 'docker run --env' to pass any of these
# variables to the user's docker instance (sf-guest)
echo "NPROC=\"$(nproc)\"
SF_CG_PARENT=\"${SF_CG_PARENT}\"
SF_DNS=\"${SF_DNS}\"
SF_TOR_IP=\"${SF_TOR_IP}\"
SF_SEED=\"${SF_SEED}\"
SF_REDIS_AUTH=\"${SF_REDIS_AUTH}\"
SF_RPC_IP=\"${SF_RPC_IP}\"
SF_NET_LG_ROUTER_IP=\"${SF_NET_LG_ROUTER_IP}\"
SF_USER=\"${SF_USER}\"
SF_DEBUG=\"${SF_DEBUG}\"
SF_BASEDIR=\"${SF_BASEDIR}\"
SF_SHMDIR=\"${SF_SHMDIR}\"
SF_RAND_OFS=\"$RANDOM\"
SF_HM_SIZE_LG=\"$SF_HM_SIZE_LG\"
SF_BACKING_FS=\"$SF_BACKING_FS\"
SF_NS_NET=\"$(readlink /proc/self/ns/net)\"
LXCFS_ARGS=($LXCFS_STR)
SF_FQDN=\"${SF_FQDN}\"" >/dev/shm/env.txt

# Note: Any host added here also needs to be added in segfaultsh with --add-host
echo "# Dynamically Generated by docker_sshd.sh
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
${SF_TOR_IP}	tor
${SF_NET_LG_ROUTER_IP}	router
${SF_DNS}	dns
${SF_RPC_IP}	rpc
${SF_RPC_IP}	sf" >"${SF_CFG_HOST_DIR}/etc/hosts"

# segfaultsh needs to create directories in here..
chown "$SF_USER" "/config/self-for-guest"

# The owner of the original socket is not known at 'docker build' time. Thus 
# we need to dynamically add it so that the shell started by SSHD can
# spwan ther SF-GUEST instance.
[[ ! -e /var/run/docker.sock ]] && { echo "Not found: /var/run/docker.sock"; echo "Try -v /var/run/docker.sock:/var/run/docker.sock"; exit 255; }
hg="docker"
addgroup -g "$(stat -c %g /var/run/docker.sock)" "${hg}" 2>/dev/null || hg="$(stat -c %G /var/run/docker.sock)" # Group already exists (e.g. 'ping')
addgroup "$SF_USER" "${hg}"
addgroup "webshell" "${hg}"
addgroup "secret" "${hg}"
chmod 770 /var/run/docker.sock

# SSHD's user (normally "root" with uid 1000) needs write access to /config/db
# That directory is mounted from the outside and we have no clue what the
# group owner or permission is. Need to add our root(uid=1000) to that group.
# However, we dont like this to be group=0 (root) and if it is then we force it
# to nogroup.
[[ "$(stat -c %g "${SF_CFG_HOST_DIR}/db/user")" -eq 0 ]] && chgrp nogroup "${SF_CFG_HOST_DIR}/db/user" # Change root -> nogroup
hg="sf-dbrw"
addgroup -g "$(stat -c %g "${SF_CFG_HOST_DIR}/db/user")" "${hg}" 2>/dev/null || hg="$(stat -c %G "${SF_CFG_HOST_DIR}/db/user")"
addgroup "${SF_USER}" "${hg}"
addgroup "webshell" "${hg}"
addgroup "secret" "${hg}"
chmod g+wx "${SF_CFG_HOST_DIR}/db/user" || exit $?

# Allow sshd's user 1000 to execute segfaultsh if mounted from extern
vboxfix /bin/segfaultsh
# Allow segfaultsh access to /sf/bin if mounted from extern (during debugging)
vboxfix /sf/bin

[[ -n $SF_DEBUG_SSHD ]] && sleep infinity
# This will execute 'segfaultsh' on root-login (uid=1000)
exec 0<&- # Close STDIN
exec /usr/sbin/sshd -u0 -D
### NOT REACHED
exit 255
