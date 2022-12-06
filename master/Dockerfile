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
              net-tools \
              netcat \
              nginx \
              tcpdump \
              wget \
              vim \
       && rm -rf /var/lib/apt/lists/*

COPY init-master.sh /
COPY /fs-root/ /
CMD ["bash", "-il"]

