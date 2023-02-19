
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
COPY init-master.sh /
COPY /cgi-bin/ /cgi-bin

RUN bash -c '{ true \
              && cp /usr/bin/nsenter /usr/bin/nsenter.u1000 \
              && chown 1000:1000 /usr/bin/nsenter.u1000 \
              && chmod ug+s /usr/bin/nsenter.u1000 \
              && setcap "CAP_SYS_ADMIN+eip" /usr/bin/nsenter.u1000 \
              && rm /usr/sbin/iptables \
              && cp /usr/sbin/xtables-nft-multi /usr/sbin/iptables \
              && chmod u+s /usr/sbin/iptables \
              && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
              && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
              && apt-get update \
              && apt-get install -y --no-install-recommends docker-ce-cli \
              && rm -f /etc/apt/sources.list.d/docker.list; }' \
       && chmod 755 /cgi-bin/rpc
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

CMD ["bash", "-il"]

