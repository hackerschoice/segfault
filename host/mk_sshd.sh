#! /bin/bash

# Executed inside alpine-gcc context to build patched sshd
# diff -u openssh-9.1p1-orig/ openssh-9.1p1-sf/

DSTDIR="/src/fs-root/usr/sbin"
DSTBIN="${DSTDIR}/sshd"
set -e
SRCDIR="/tmp/openssh-9.1p1"
[[ ! -d "$SRCDIR" ]] && {
	wget -O - https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.1p1.tar.gz | tar xfz -

	cd "$SRCDIR"

	patch -p1 </src/sf-sshd.patch
}
cd "$SRCDIR"
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-libs=-lcap \
		--disable-utmp \
		--disable-wtmp \
		--disable-utmpx \
		--disable-wtmpx \
		--disable-security-key \
		--disable-lastlog \
		--with-privsep-path=/var/empty \
		--with-privsep-user=sshd \
		--with-ssl-engine

make sshd
strip sshd
[[ ! -d "${DSTDIR}" ]] && mkdir -p "${DSTDIR}"
cp sshd "${DSTBIN}"
chmod 755 "${DSTBIN}"
rm -rf "${SRCDIR:?}"

