FROM alpine

# SF-HOST

RUN	apk add --no-cache --upgrade \
	&& apk add --no-cache \
		docker-cli \
		bash \
		xauth \
		openssh-server

COPY /fs-root/ /

RUN echo "/bin/segfaultsh" >>/etc/shells

CMD ["/bin/docker_sshd.sh"]

