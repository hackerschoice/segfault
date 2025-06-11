
# VER=10.0p1
# Version >9.9p1 requires a rework of the patch so that sshd-auth compiles without sf_done references etc.
VER=9.9p2
.PHONY: albuild clean diff rm all

all: albuild fs-root/bin/docker-exec-sigproxy fs-root/bin/unix-socket-client fs-root/usr/sbin/sshd Dockerfile
	docker build --network host -t sf-host .
	# docker build --no-cache --network host -t sf-host .

albuild:
	bash -c "docker run --network host --rm sf-alpine-gcc true || \
		docker commit sf-alpine-gcc sf-alpine-gcc || { \
		docker run --network host --name sf-alpine-gcc alpine sh -c 'apk update && apk add gcc patch libc-dev musl-dev zlib-dev openssl-dev make linux-headers libcap-dev bash' \
		&& docker commit sf-alpine-gcc sf-alpine-gcc; }"

# See mk_sshd.sh for manual debugging
fs-root/usr/sbin/sshd: Makefile sf-sshd.patch mk_sshd.sh
# fs-root/usr/sbin/sshd: sf-sshd.patch mk_sshd.sh
	make rm
	docker run --network host --rm -v$$(pwd):/src -w /tmp --env VER=$(VER) sf-alpine-gcc /src/mk_sshd.sh
	@echo "Type 'make diff' to create a sf-sshd-$(VER).patch"

fs-root/bin/docker-exec-sigproxy: docker-exec-sigproxy.c
	docker run --network host --rm -v$$(pwd):/src -w /src sf-alpine-gcc gcc -Wall -O2 -o fs-root/bin/docker-exec-sigproxy docker-exec-sigproxy.c
	@echo SUCCESS

fs-root/bin/unix-socket-client: unix-socket-client.c
	docker run --network host --rm -v$$(pwd):/src -w /src sf-alpine-gcc gcc -Wall -O2 -o fs-root/bin/unix-socket-client unix-socket-client.c
	@echo SUCCESS

diff:
	cd dev && \
	diff -x '!*.[ch]' -u   openssh-$(VER)-orig/  openssh-$(VER)-sf/  | grep -Ev ^"(Only in|Common)" >../sf-sshd-$(VER).patch
	@echo "May want to 'mv sf-sshd-$(VER).patch sf-sshd.patch'."

rm:
	rm -rf dev/openssh-$(VER)-orig dev/openssh-$(VER)-sf fs-root/usr/sbin/sshd

clean: rm
	docker image rm sf-alpine-gcc

