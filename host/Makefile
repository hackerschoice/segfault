all: albuild fs-root/bin/docker-exec-sigproxy fs-root/usr/sbin/sshd Dockerfile
	docker build --network host -t sf-host .

albuild:
	bash -c "docker run --rm alpine-gcc true || \
		docker commit alpine-gcc alpine-gcc || { \
		docker run --network host --name alpine-gcc alpine sh -c 'apk update && apk add gcc patch libc-dev musl-dev zlib-dev openssl-dev make linux-headers libcap-dev bash' \
		&& docker commit alpine-gcc alpine-gcc; }"

fs-root/usr/sbin/sshd: sf-sshd.patch mk_sshd.sh
	docker run --rm -v$$(pwd):/src --net=host -w /tmp alpine-gcc /src/mk_sshd.sh

fs-root/bin/docker-exec-sigproxy: docker-exec-sigproxy.c
	docker run --rm -v$$(pwd):/src -w /src alpine-gcc gcc -Wall -O2 -o fs-root/bin/docker-exec-sigproxy docker-exec-sigproxy.c
	@echo SUCCESS

diff:
	cd dev && \
	diff -x '!*.[ch]' -u   openssh-9.1p1-orig/  openssh-9.1p1-sf/  | grep -Ev ^"(Only in|Common)" >../sf-sshd.patch

clean:
	rm -rf openssh-9.1p1-sf fs-root/usr/sfbin/sshd
	docker image rm alpine-gcc

