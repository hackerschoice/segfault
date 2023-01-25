#! /bin/bash

# Executed inside alpine-gcc context to build patched sshd

set -e
SRCDIR="/src/openssh-9.1p1-sf"
[[ ! -d "$SRCDIR" ]] && {
	cd /src
	wget -O - https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.1p1.tar.gz | tar xfz -
	mv /src/openssh-9.1p1 "$SRCDIR"
	cd "$SRCDIR"
	patch -p1 <../sf-sshd.patch
}
cd "$SRCDIR"

./configure --prefix=/usr --sysconfdir=/etc/ssh --with-libs=-lcap
make
strip sshd
[[ ! -d /src/fs-root/usr/sbin ]] && mkdir -p /src/fs-root/usr/sbin
cp sshd /src/fs-root/usr/sbin/sshd
chmod 755 /src/fs-root/usr/sbin/sshd
rm -rf "${SRCDIR:?}"

