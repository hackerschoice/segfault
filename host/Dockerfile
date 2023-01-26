FROM alpine

# SF-HOST

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		redis \
		bash \
		libcap \
		xauth \
		openssh-server \
		jq \
		xfsprogs-extra \
	&& echo "/bin/segfaultsh" >>/etc/shells
COPY /fs-root/ /

CMD ["/bin/docker_sshd.sh"]

