FROM alpine:latest

RUN \
	apk add --no-cache --upgrade && \
	apk add --no-cache \
		docker-cli \
		bash \
		encfs

ADD mount.sh /

CMD ["/mount.sh"]
