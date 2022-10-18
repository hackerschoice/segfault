FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
		docker-cli \
		encfs \
		redis \
		xfsprogs-extra
COPY destructor.sh encfsd.sh portd.sh /
