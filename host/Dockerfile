FROM alpine

# SF-HOST

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
		docker-cli \
		iptables \
		jq \
		libcap \
		openssh-client \
		openssh-server \
		redis \
		strace \
		vim \
		xauth \
		xfsprogs-extra

COPY setup.sh /fs-root/ /
RUN		/setup.sh && rm -f /setup.sh

CMD ["/bin/docker_sshd.sh"]

