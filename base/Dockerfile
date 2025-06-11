FROM ubuntu:latest
RUN	apt-get update \
	&& apt-get install -y --no-install-recommends \
		binutils \
		ca-certificates \
		conntrack \
		curl \
		dnsutils \
		fcgiwrap \
		file \
		fping \
		gnupg \
		inetutils-ping \
		iptables \
		iproute2 \
		iperf \
		ipset \
		jq \
		less \
		lsb-release \
		net-tools \
		netcat-traditional \
		nginx \
		openvpn \
		psmisc \
		redis-tools \
		strace \
		tcpdump \
		wireguard-tools \
		wget \
		vim \
	&& bash -c '{ true \
		&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
		&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
		&& apt-get update \
		&& apt-get install -y --no-install-recommends docker-ce-cli \
		&& rm -f /etc/apt/sources.list.d/docker.list; }' \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/ \
	&& bash -c 'echo "source /dev/shm/net-devs.txt 2>/dev/null" >>/root/.bashrc'

	# COPY ../guest/fs-root/sf/bin/pkg-install.sh /usr/sbin
