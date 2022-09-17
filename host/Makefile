all: fs-root/bin/docker-exec-sigproxy Dockerfile
	docker build -t sf-host .

fs-root/bin/docker-exec-sigproxy: docker-exec-sigproxy.c
	-docker run --name alpine-gcc alpine sh -c "apk update && apk add gcc libc-dev" \
	&& docker commit alpine-gcc alpine-gcc
	docker run --rm -v$$(pwd):/src -w /src alpine-gcc gcc -Wall -O2 -o fs-root/bin/docker-exec-sigproxy docker-exec-sigproxy.c
	@echo SUCCESS

