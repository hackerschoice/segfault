#! /bin/bash

# This is the entry point for L0PHT-HOST (e.g. host/Dockerfile)
# Fix ownership if mounted from within vbox
[[ -e /etc/ssh/l0pht/ssh_host_rsa_key ]] || {
	echo -e \
"\033[1;31mSSH Key not found in /etc/ssh/l0pht\033[00m. You must create them first and the
start docker with the additional '-v' option below:

mkdir -p ~/l0pht/cfg/etc/ssh && ssh-keygen -A ~/l0pht/cfg && \\
docker run --r -p 22:2222 -v /var/run/docker.sock:/var/run/docker.sock \\
	-v ~/l0pht/etc/ssh:/etc/ssh/l0pht:ro \\
	--name l0pht-host -it l0pth-host"
	exit 255
}

# The owner of the original socket is not known at 'docker build' time. Thus 
# we need to dynamically add it so that the shell started by SSHD can
# spwan ther L0PHT-GUEST docker.
[[ ! -e /var/run/docker.sock ]] && { echo "Not found: /var/run/docker.sock"; echo "Try -v -v /var/run/docker.sock:/var/run/docker.sock"; exit 255; }
echo "docker:x:$(stat -c %g /var/run/docker.sock):${LUSER}" >>/etc/group && \
chmod 770 /var/run/docker.sock && \
# SSHD clears all the environment. We need to pass the location of the 'l0pht-guest'
# directory of the outter most host to the guest-shell.
echo 'LGUESTDIR="'"${LGUESTDIR}"'"' >/tmp/lguestdir.txt
/usr/sbin/sshd -p 2222

exec sleep infinite

