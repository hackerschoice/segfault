#! /bin/bash

# Executed inside alpine-gcc context to build patched sshd
# diff -x '!*.[ch]' -u -r openssh-9.2p1-orig openssh-9.2p1-sf | grep -v ^Only

# Manual debugging:
# cd /research/segfault/host
# docker run --rm -v$(pwd):/host --net=host -it alpine-gcc bash -il
# export PS1='ssh-build:\w\$ '

DSTDIR="/src/fs-root/usr/sbin"
DSTBIN="${DSTDIR}/sshd"
set -e
SRCDIR="/src/dev/openssh-${VER:?}-sf"
[[ ! -d "/src/dev" ]] && mkdir -p "/src/dev"
cd /src/dev
[[ ! -d "$SRCDIR" ]] && {
	# Cloudflare to often returns 503 - "BLOCKED"
	# wget -O- https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.2p1.tar.gz | tar xfz -
	wget "https://artfiles.org/openbsd/OpenSSH/portable/openssh-${VER}.tar.gz"
	tar xfz "openssh-${VER}.tar.gz"
	mv "openssh-${VER}" "openssh-${VER}-orig"
	tar xfz "openssh-${VER}.tar.gz"
	mv "openssh-${VER}" "${SRCDIR}"

	cd "$SRCDIR"

	patch -p1 </src/sf-sshd.patch
}
cd "$SRCDIR"
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-libs=-lcap \
		--without-zlib-version-check \
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
# rm -rf "${SRCDIR:?}"

