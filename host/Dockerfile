FROM alpine

# SF-HOST
COPY /fs-root/ /

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		bash \
		xauth \
		openssh-server \
	&& echo "/bin/segfaultsh" >>/etc/shells

CMD ["/bin/docker_sshd.sh"]

