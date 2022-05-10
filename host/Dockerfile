FROM alpine:latest

# SF-HOST

# SSHD clears all environment variable before spwaning shell.
# Any variable that needs to be available inside shell 'segfaultsh'
# needs to be added to docker_sshd.sh
ENV LUSER="${LUSER:-root}"
ENV LUSERPASSWORD="${LUSERPASSWORD:-segfault}"
ENV LDNS="${LDNS:-172.24.0.2}"
ENV SF_FQDN="${SF_FQDN:-segfault.thc.org}"
ENV LENCFS_SECDIR="${LENCFS_SECDIR:-/dev/shm/encfs-sec}"
ENV LENCFS_RAWDIR="${LENCFS_RAWDIR:-/dev/shm}"
ENV SF_SRCDIR="${SF_SRCDIR:-/dev/null}"
ENV SF_DEBUG="${SF_DEBUG}"
ENV SF_BASEDIR="${SF_BASEDIR:-/dev/null}"

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

