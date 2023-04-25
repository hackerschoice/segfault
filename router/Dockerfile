# iptables 'nft' needs rolling.
# FROM ubuntu:rolling
FROM ubuntu:22.04
RUN    apt-get update \
       && apt-get install -y --no-install-recommends \
              ca-certificates \
              conntrack \
              curl \
              fping \
              inetutils-ping \
              iptables \
              iproute2 \
              iperf \
              jq \
              lsb-release \
              gnupg \
              net-tools \
              netcat-traditional \
              tcpdump \
              wireguard-tools \
              wget \
              vim

# RUN    apt-get install -y --no-install-recommends \
#               nftables

RUN bash -c '{ true \
              && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
              && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
              && apt-get update \
              && apt-get install -y --no-install-recommends docker-ce-cli; }' \
       && rm -rf /var/lib/apt/lists/*

COPY user-limit.sh init.sh init-wg.sh init-novpn.sh fix-network.sh /
CMD ["bash", "-il"]

