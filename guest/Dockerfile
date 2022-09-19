FROM kalilinux/kali-rolling

WORKDIR /root/

# Valid options are:
#   MINI BASE DEVEL NET HACK LARGE HUGE ALL
#   SF_PACKAGES=ALL make
ARG SF_PACKAGES=${SF_PACKAGES:-"MINI BASE NET"}

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
		less \
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
		libc-devtools \
		libevent-dev \
		libssl-dev \
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
		weevely \
	&& /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		ngrep \
		openssh-client \
		virtualenv \
		mtr \
		wipe \
		htop \
		most \
		dstat \
		proxychains \
		gnupg \
		pip \
		python-is-python3 \
		jq \
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
		enum4linux \
		ldap-utils \
		peass \
		hashcat \
		john \
		altdns \
		dnsrecon \
		dirsearch \
		recon-ng \
	&& /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		default-jdk \
		exploitdb \
		gem \
		golang-go \
		npm \
		nodejs \
		php \
		pkg-config \
		rust-all \
		ruby \
		x11-apps \
	&& /pkg-install.sh LARGE pip install --pre scapy[basic] \
	&& /pkg-install.sh LARGE pip install \
		git-dumper \
		ipyton \
		shodan \
	&& /pkg-install.sh HACK pip install sqlmap \
	&& /pkg-install.sh DEVEL pip install \
		cryptocode \
		colorama \
	&& /pkg-install.sh LARGE curl -fsSL https://github.com/Peltoche/lsd/releases/download/0.21.0/lsd_0.21.0_amd64.deb -o /tmp/lsd.deb \
	&& /pkg-install.sh LARGE dpkg -i /tmp/lsd.deb \
	&& /pkg-install.sh LARGE curl -fsSL https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.0/geonet_0.4.0_amd64.deb -o /tmp/geonet.deb \
	&& /pkg-install.sh LARGE dpkg -i /tmp/geonet.deb \
	&& /pkg-install.sh MINI bash -c "{ [[ -f /usr/share/locale/locale.alias ]] && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; }" \
	&& /pkg-install.sh DEVEL bash -c "{ [[ $(uname -m) = "x86_64" ]] && apt-get install -y --no-install-recommends linux-headers-amd64; }" \
	&& { rm -f /tmp/*.deb; true; } \
	&& /pkg-install.sh HACK bash -c "curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xfvz - -C /usr/local/bin"

# Keep the apt/lists in case user does an apt update -y
#RUN rm -rf /var/lib/apt/lists/*

# Do fs-root last (on vmbox it messes with chmod and setup.sh fixes it)
COPY /fs-root/ /
RUN		/setup.sh \
	&& rm -f /setup.sh /pkt-install.sh

CMD ["zsh", "-il"]
