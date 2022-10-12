FROM ubuntu:22.04
RUN    apt-get update \
       && apt-get install -y --no-install-recommends curl \
              ca-certificates \
              curl \
              fping \
              inetutils-ping \
              iptables \
              iproute2 \
              iperf \
              net-tools \
              netcat \
              tcpdump \
              wget \
              vim \
       && rm -rf /var/lib/apt/lists/*

COPY tc.sh init.sh fix-network.sh /
CMD ["bash", "-il"]

