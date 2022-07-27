FROM alpine:latest

# SF-HOST

# SSHD clears all environment variable before spwaning shell.
# Any variable that needs to be available inside shell 'segfaultsh'
# needs to be added to docker_sshd.sh
ENV SF_USER="${SF_USER:-root}"
ENV SF_USER_PASSWORD="${SF_USER_PASSWORD:-segfault}"
ENV SF_DNS="${SF_DNS:-10.11.255.252}"
ENV SF_FQDN="${SF_FQDN:-SETME.segfault.net}"
ENV SF_ENCFS_SECDIR="${SF_ENCFS_SECDIR:-/dev/shm/encfs-sec}"
ENV SF_DEBUG="${SF_DEBUG}"

RUN \
	apk add --no-cache --upgrade && \
	apk add --no-cache \
		docker-cli \
		bash \
		openssh-server

COPY /fs-root/ /

COPY setup.sh /
RUN /setup.sh && \
	rm -f /setup.sh

CMD ["/bin/docker_sshd.sh"]

