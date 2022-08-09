FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		bash \
		encfs

COPY mount.sh /

CMD ["/mount.sh"]
