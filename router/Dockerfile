FROM ubuntu:22.04
RUN    apt-get update \
       && apt-get install -y --no-install-recommends \
              ca-certificates \
              curl \
              fping \
              inetutils-ping \
              iptables \
              iproute2 \
              iperf \
              lsb-release \
              gnupg \
              net-tools \
              netcat \
              tcpdump \
              wireguard-tools \
              wget \
              vim

RUN bash -c '{ true \
              && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
              && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
              && apt-get update \
              && apt-get install -y --no-install-recommends docker-ce-cli; }' \
       && rm -rf /var/lib/apt/lists/*

COPY tc.sh init.sh init-wg.sh fix-network.sh /
CMD ["bash", "-il"]

