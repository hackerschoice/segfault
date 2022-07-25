FROM ubuntu:22.04
RUN apt update && \
       apt install -y --no-install-recommends curl \
       wget \
       ca-certificates \
       net-tools \
       inetutils-ping \
       netcat \
	iptables \
	iproute2 \
       tcpdump && \
       echo DONE

COPY init.sh fix-network.sh /
CMD ["bash", "-il"]

