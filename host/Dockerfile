FROM alpine

# SF-HOST
COPY /fs-root/ /

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		redis \
		bash \
		xauth \
		openssh-server \
		jq \
		xfsprogs-extra \
	&& echo "/bin/segfaultsh" >>/etc/shells

CMD ["/bin/docker_sshd.sh"]

