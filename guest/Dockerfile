FROM kalilinux/kali-rolling

WORKDIR /root/

# ENV SF_PACKAGES=MINI
ENV SF_PACKAGES=${SF_PACKAGES:-"MINI BASE NET"}
# ENV SF_PACKAGES=MINI BASE DEVEL NET HACK FULL

COPY /fs-root/ /
COPY setup.sh pkg-install.sh /

RUN	apt-get update -y \
	&& /pkg-install.sh MINI apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		iputils-ping \
		iproute2 \
		lsb-release \
		locales \
		net-tools \
		procps \
		psmisc \
		vim \
		zsh \
		zsh-autosuggestions \
		zsh-syntax-highlighting \
	&& /pkg-install.sh BASE apt-get install -y --no-install-recommends \
		bc \
		openssh-sftp-server \
		screen \
		tmux \
		xxd \
	&& /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
		automake \
		binutils \
		bison \
		build-essential \
		byacc \
		flex \
		g++ \
		gcc \
		gdb \
		git \
		hexedit \
		ltrace \
		make \
		patch \
		strace \
	&& /pkg-install.sh NET apt-get install -y --no-install-recommends \
		dnsutils \
		iputils-tracepath \
		gsocket \
		nano \
		netcat-traditional \
		man-db \
		manpages-dev \
		rsync \
		sudo \
		traceroute \
		wget \
		whois \
	&& /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		hydra \
		irssi \
		nmap \
		pagekite \
		socat \
		thc-ipv6 \
	&& /pkg-install.sh FULL apt-get install -y --no-install-recommends \
		ngrep \
		python-is-python3 \
		openssh-client \
		php \
		virtualenv \
		mtr \
		wipe \
		htop \
		dstat \
		proxychains \
		gnupg \
		pip \
		jq \
		less \
		mc \
		tree \
		apache2-utils \
		lsof \
		dirb \
		bat \
		duf \
		unzip \
		rclone \
		rlwrap \
		lynx \
		whatweb \
		commix \
		nikto \
		exiftool \
		wpscan \
		smbclient \
		smbmap \
		sslscan \
		sshpass \
		ssh-audit \
		theharvester \
		emailharvester \
		cmseek \
		exploitdb \
		enum4linux \
		ldap-utils \
		peass \
		hashcat \
		john \
		altdns \
		dnsrecon \
		dirsearch \
		recon-ng \
		golang-go \
		rust-all \
		npm \
		nodejs \
		pkg-config \
		x11-apps \
	&& /pkg-install.sh FULL pip install ipython \
	&& /pkg-install.sh FULL pip install --pre scapy[basic] \
	&& /pkg-install.sh FULL pip install git-dumper \
	&& /pkg-install.sh FULL pip install shodan \
	&& /pkg-install.sh FULL curl -fsSL https://github.com/Peltoche/lsd/releases/download/0.21.0/lsd_0.21.0_amd64.deb -o /tmp/lsd.deb \
	&& /pkg-install.sh FULL dpkg -i /tmp/lsd.deb \
	&& /pkg-install.sh FULL curl -fsSL https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.0/geonet_0.4.0_amd64.deb \
	&& /pkg-install.sh FULL dpkg -i /tmp/geonet_0.4.0_amd64.deb \
	&& /pkg-install.sh FULL curl -fsSL https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.0/geonet_0.4.0_amd64.deb -o /tmp/geonet.deb \
	&& /pkg-install.sh FULL dpkg -i /tmp/geonet.deb \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
	&& { rm -f /tmp/*.deb; true; } \
	&& /pkg-install.sh HACK bash -c "curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xfvz - -C /usr/local/bin" \
	&& /setup.sh \
	&& rm -f /setup.sh /pkg-install.sh
# Keep the apt/lists in case user does a apt update -y
#RUN rm -rf /var/lib/apt/lists/*

CMD ["zsh", "-il"]
