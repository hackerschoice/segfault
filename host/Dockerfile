FROM alpine

# SF-HOST

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
		docker-cli \
		iptables \
		jq \
		libcap \
		openssh-server \
		redis \
		xauth \
		xfsprogs-extra \
	&& echo "/bin/segfaultsh" >>/etc/shells
COPY /fs-root/ /

CMD ["/bin/docker_sshd.sh"]

