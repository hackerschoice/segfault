FROM ubuntu:22.04
RUN apt-get update && \
       apt-get install -y --no-install-recommends curl \
       wget \
       ca-certificates \
       net-tools \
       inetutils-ping \
       netcat \
	iptables \
	iproute2 \
	iperf \
       tcpdump && \
       rm -rf /var/lib/apt/lists/* && \
       echo DONE

COPY tc.sh init.sh fix-network.sh /
CMD ["bash", "-il"]

