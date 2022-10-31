FROM kalilinux/kali-rolling

WORKDIR /root/

# Valid options are:
#   MINI BASE DEVEL NET WEB HACK LARGE HUGE ALL
#   SF_PACKAGES=ALL make
# Default is "MINI BASE NET" (see pkg-install.sh)
ARG SF_PACKAGES

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
		rsync \
		vim \
		zsh \
		zsh-autosuggestions \
		zsh-syntax-highlighting \
	&& /pkg-install.sh BASE apt-get install -y --no-install-recommends \
		bc \
		bsdmainutils \
		dos2unix \
		file \
		less \
		openssh-sftp-server \
		python3-pip \
		screen \
		sharutils \
		tmux \
		unzip \
		xxd \
	&& /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
		automake \
		binutils \
		bison \
		build-essential \
		byacc \
		flex \
		g++ \
		gawk \
		gcc \
		gdb \
		git \
		hexedit \
		html2text \
		libc-devtools \
		libevent-dev \
		libssl-dev \
		ltrace \
		make \
		patch \
		strace \
		whiptail \
		xterm \
	&& /pkg-install.sh NET apt-get install -y --no-install-recommends \
		dnsutils \
		ftp \
		iftop \
		iputils-tracepath \
		gsocket \
		nano \
		netcat-traditional \
		man-db \
		manpages-dev \
		sudo \
		tcpdump \
		traceroute \
		wireguard-tools \
		wget \
		whois \
	&& DEBIAN_FRONTEND=noninteractive /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		assetfinder \
		dnsmap \
		ffuf \
		hydra \
		gobuster \
		irssi \
		nbtscan \
		netdiscover \
		nmap \
		pagekite \
		shadowsocks-libev \
		shadowsocks-v2ray-plugin \
		snmpcheck \
		socat \
		thc-ipv6 \
		tshark \
		webshells \
		weevely \
	&& /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		altdns \
		apache2-utils \
		bat \
		cmseek \
		commix \
		dirb \
		dirsearch \
		dnsrecon \
		dotnet-runtime-6.0 \
		dstat \
		duf \
		emacs \
		emailharvester \
		enum4linux \
		exiftool \
		gnupg \
		hashcat \
		htop \
		ldap-utils \
		joe \
		john \
		jq \
		lsof \
		lynx \
		mc \
		mg \
		mtr \
		most \
		neofetch \
		nikto \
		ngrep \
		openssh-client \
		p7zip-full \
		peass \
		pip \
		proxychains \
		python-is-python3 \
		python3-venv \
		python3-virtualenv \
		recon-ng \
		rclone \
		rlwrap \
		smbclient \
		smbmap \
		snmp \
		speedtest-cli \
		sslscan \
		sshpass \
		ssh-audit \
		theharvester \
		tree \
		w3m \
		weechat weechat-plugins weechat-matrix \
		whatweb \
		wipe \
		wpscan \
		wrk \
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
	&& /pkg-install.sh HUGE go install -v github.com/projectdiscovery/uncover/cmd/uncover@latest \
	&& /pkg-install.sh HUGE go install -v github.com/sagernet/sing-box/cmd/sing-box@latest \
	&& /pkg-install.sh HUGE go install -v github.com/tomnomnom/waybackurls@latest \
	&& /pkg-install.sh LARGE pip install --pre 'scapy[basic]' \
	&& /pkg-install.sh WEB pip install \
		'pelican[Markdown]' \
	&& /pkg-install.sh LARGE pip install \
		git-dumper \
		ipython \
		shodan \
	&& /pkg-install.sh HACK pip install \
		hashid \
		sqlmap \
	&& /pkg-install.sh HACK bash -c "{ curl -fsSL https://github.com/projectdiscovery/uncover/releases/download/v0.0.8/uncover_0.0.8_linux_amd64.zip -o /tmp/pkg.zip \
		&& unzip /tmp/pkg.zip uncover -d /usr/bin && rm -f /tmp/pkg.zip \
		&& curl -fsSL https://github.com/projectdiscovery/httpx/releases/download/v1.2.4/httpx_1.2.4_linux_amd64.zip -o /tmp/pkg.zip \
		&& unzip /tmp/pkg.zip httpx -d /usr/bin && rm -f /tmp/pkg.zip \
		&& curl -fsSL https://github.com/projectdiscovery/nuclei/releases/download/v2.7.7/nuclei_2.7.7_linux_amd64.zip -o /tmp/pkg.zip \
		&& unzip /tmp/pkg.zip nuclei -d /usr/bin && rm -f /tmp/pkg.zip; }" \
	&& /pkg-install.sh DEVEL pip install \
		cryptocode \
		colorama \
		PyCryptodome \
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
	&& rm -f /setup.sh /pkg-install.sh

CMD ["zsh", "-il"]
