FROM alpine:latest

ENV LUSER=user
ENV LGUESTDIR=/research/l0pht/guest/l0pht-guest

RUN \
	apk add --no-cache --upgrade && \
	apk add --no-cache \
		docker-cli \
		bash \
		openssh-server

COPY /fs-root/ /

COPY setup.sh /tmp
RUN /tmp/setup.sh && \
	rm -f /tmp/setup.sh

CMD ["/bin/docker_sshd.sh"]

