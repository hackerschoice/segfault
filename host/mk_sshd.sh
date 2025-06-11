#! /bin/bash

# Executed inside alpine-gcc context to build patched sshd
# diff -x '!*.[ch]' -u -r openssh-9.2p1-orig openssh-9.2p1-sf | grep -v ^Only

# Manual debugging:
# cd /research/segfault/host
# docker run --rm -v$(pwd):/src --net=host -it alpine-gcc bash -il
# export PS1='ssh-build:\w\$ '

DSTDIR="/src/fs-root/usr/sbin"
DSTLBX="/src/fs-root/usr/libexec"
DSTBIN="${DSTDIR}/sshd"
set -e
SRCDIR="/src/dev/openssh-${VER:?}-sf"
[[ ! -d "/src/dev" ]] && mkdir -p "/src/dev"
cd /src/dev
[[ ! -d "$SRCDIR" ]] && {
	# Cloudflare to often returns 503 - "BLOCKED"
	# wget -O- https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.2p1.tar.gz | tar xfz -
	rm -rf "openssh-${VER}-orig" 2>/dev/null
	[ ! -f "openssh-${VER}.tar.gz" ] && wget "https://artfiles.org/openbsd/OpenSSH/portable/openssh-${VER}.tar.gz"
	tar xfz "openssh-${VER}.tar.gz"
	mv "openssh-${VER}" "openssh-${VER}-orig"
	tar xfz "openssh-${VER}.tar.gz"
	mv "openssh-${VER}" "${SRCDIR}"

	cd "$SRCDIR"

	patch -p1 <"/src/sf-sshd.patch"
	# musl 9.8p1 bug
	# sed 's|fd, \&addr|fd, (struct sockaddr *)\&addr|' -i "${SRCDIR}/openbsd-compat/port-linux.c"
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

make sshd sshd-session
strip sshd sshd-session
# make sshd sshd-session sshd-auth
# strip sshd sshd-session sshd-auth
[[ ! -d "${DSTDIR}" ]] && mkdir -p "${DSTDIR}"
[[ ! -d "${DSTLBX}" ]] && mkdir -p "${DSTLBX}"
cp sshd "${DSTBIN}"
cp sshd-session "${DSTLBX}"
chmod 755 "${DSTBIN}" "${DSTLBX}/sshd-session"
# cp sshd-session sshd-auth "${DSTLBX}"
# chmod 755 "${DSTBIN}" "${DSTLBX}/sshd-session" "${DSTLBX}/sshd-auth"
# rm -rf "${SRCDIR:?}"

