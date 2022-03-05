FROM alpine:latest

ENV LUSER=user
ENV LGUESTDIR=/usr/local/l0pht-guest

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

# FROM ghcr.io/linuxserver/baseimage-alpine:3.14

# RUN \
#   echo "**** install runtime packages ****" && \
#   apk add --no-cache --upgrade && \
#   apk add --no-cache \
#   	docker-cli \
#   	openssh-server && \
#   	sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
#   	userdel abc && \
#   	echo "/bin/l0phtsh" >>/etc/shells && \
#   	adduser -D user -s /bin/l0phtsh && \
#   	usermod -p "" user && \
# 	echo DONE

# COPY /fs-root/ /
