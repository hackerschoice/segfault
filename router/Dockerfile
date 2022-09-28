FROM ubuntu:22.04
RUN    apt-get update \
       && apt-get install -y --no-install-recommends curl \
              wget \
              curl \
              ca-certificates \
              net-tools \
              inetutils-ping \
              netcat \
              iptables \
              iproute2 \
              iperf \
              tcpdump \
              fping \
       && rm -rf /var/lib/apt/lists/*

COPY tc.sh init.sh fix-network.sh /
CMD ["bash", "-il"]

