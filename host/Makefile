
VER=9.8p1

all: albuild fs-root/bin/docker-exec-sigproxy fs-root/bin/unix-socket-client fs-root/usr/sbin/sshd Dockerfile
	docker build --no-cache --network host -t sf-host .

albuild:
	bash -c "docker run --rm sf-alpine-gcc true || \
		docker commit sf-alpine-gcc sf-alpine-gcc || { \
		docker run --network host --name sf-alpine-gcc alpine sh -c 'apk update && apk add gcc patch libc-dev musl-dev zlib-dev openssl-dev make linux-headers libcap-dev bash' \
		&& docker commit sf-alpine-gcc sf-alpine-gcc; }"

# See mk_sshd.sh for manual debugging
fs-root/usr/sbin/sshd: albuild sf-sshd.patch mk_sshd.sh
	docker run --rm -v$$(pwd):/src --net=host -w /tmp --env VER=$(VER) sf-alpine-gcc /src/mk_sshd.sh
	@echo "Type 'make diff' to create a sf-sshd-$(VER).patch"

fs-root/bin/docker-exec-sigproxy: docker-exec-sigproxy.c
	docker run --rm -v$$(pwd):/src -w /src sf-alpine-gcc gcc -Wall -O2 -o fs-root/bin/docker-exec-sigproxy docker-exec-sigproxy.c
	@echo SUCCESS

fs-root/bin/unix-socket-client: unix-socket-client.c
	docker run --rm -v$$(pwd):/src -w /src sf-alpine-gcc gcc -Wall -O2 -o fs-root/bin/unix-socket-client unix-socket-client.c
	@echo SUCCESS

diff:
	cd dev && \
	diff -x '!*.[ch]' -u   openssh-$(VER)-orig/  openssh-$(VER)-sf/  | grep -Ev ^"(Only in|Common)" >../sf-sshd-$(VER).patch
	@echo "May want to 'mv sf-sshd-$(VER).patch sf-sshd.patch'."

clean:
	rm -rf openssh-$(VER)-orig openssh-$(VER)-sf fs-root/usr/sbin/sshd
	docker image rm sf-alpine-gcc

