FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		redis \
		bash \
		encfs
COPY destructor.sh encfsd.sh portd.sh /
