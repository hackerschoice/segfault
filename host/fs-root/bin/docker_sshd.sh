#! /bin/bash

# This is the entry point for L0PHT-HOST (e.g. host/Dockerfile)

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

