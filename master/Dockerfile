
# sf-master
FROM ubuntu:22.04
RUN    apt-get update \
       && apt-get install -y --no-install-recommends \
              ca-certificates \
              curl \
              fcgiwrap \
              fping \
              gnupg \
              inetutils-ping \
              iptables \
              iproute2 \
              iperf \
              lsb-release \
              net-tools \
              netcat \
              nginx \
              psmisc \
              redis-tools \
              tcpdump \
              wget \
              wireguard-tools \
              vim

# Alpine's fcgiwrap does not support '-p' :/
# FROM alpine
# RUN    apk add --no-cache --upgrade \
#        && apk add --no-cache \
#               bash \
#               curl \
#               docker-cli \
#               fcgiwrap \
#               fping \
#               iptables \
#               iproute2 \
#               net-tools \
#               `#nginx` \
#               psmisc \
#               redis \
#               `#tcpdump` \
#               wget \
#               wireguard-tools \
#               vim


COPY setup.sh init-master.sh /
COPY /cgi-bin /cgi-bin
RUN /setup.sh
CMD ["bash", "-il"]

