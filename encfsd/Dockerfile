FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
		cgroup-tools \
		curl \
		docker-cli \
		encfs \
		redis \
		xfsprogs-extra
COPY destructor.sh funcs_destructor.sh encfsd.sh portd.sh /
