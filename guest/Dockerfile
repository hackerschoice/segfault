FROM kalilinux/kali-rolling

WORKDIR /root/

# Valid options are:
#   MINI BASE DEVEL NET WEB HACK LARGE HUGE ALL
#   SF_PACKAGES=ALL make
# Default is "MINI BASE NET" (see pkg-install.sh)
ARG SF_PACKAGES

COPY setup.sh fs-root/sf/bin/pkg-install.sh /

RUN	apt-get update -y \
	&& /pkg-install.sh MINI apt-get install -y --no-install-recommends \
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
		ca-certificates \
		curl \
		dos2unix \
		file \
		git \
		jq \
		less \
		openssh-sftp-server \
		python3-pip \
		screen \
		sharutils \
		supervisor \
		tmux \
		unzip \
		xxd \
	&& /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
		automake \
		binutils \
		bison \
		build-essential \
		byacc \
		dtach \
		flex \
		g++ \
		gawk \
		gcc \
		gdb \
		grc \
		hexedit \
		html2text \
		libc-devtools \
		libevent-dev \
		libssl-dev \
		ltrace \
		make \
		patch \
		pv \
		source-highlight \
		strace \
		wdiff \
		whiptail \
		xterm \
	&& /pkg-install.sh NET apt-get install -y --no-install-recommends \
		dnsutils \
		ftp \
		iftop \
		iputils-tracepath \
		gsocket \
		man-db \
		manpages-dev \
		mosh \
		nano \
		netcat-traditional \
		ntpdate \
		rpcbind \
		sockstat \
		sudo \
		tcpdump \
		tcpick \
		telnet \
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
		impacket-scripts \
		irssi \
		nbtscan \
		netdiscover \
		ncrack \
		nmap \
		onesixtyone \
		oracle-instantclient-sqlplus \
		oscanner \
		pagekite \
		shadowsocks-libev \
		shadowsocks-v2ray-plugin \
		snmpcheck \
		socat \
		thc-ipv6 \
		tnscmd10g \
		tshark \
		webshells \
		weevely \
	&& /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		altdns \
		apache2-utils \
		apt-file \
		bat \
		cmseek \
		commix \
		dirb \
		dirsearch \
		dnsenum \
		dnsrecon \
		dotnet-runtime-6.0 \
		dstat \
		duf \
		elinks \
		emacs \
		emailharvester \
		enum4linux \
		evil-winrm \
		eyewitness \
		exa \
		exiftool \
		fd-find \
		fzf \
		gnupg \
		hashcat \
		highlight \
		htop \
		ldap-utils \
		joe \
		john \
		lsof \
		lynx \
		mc \
		mg \
		mtr \
		most \
		mycli \
		mypager \
		nfs-common \
		neofetch \
		neovim \
		ngrep \
		nikto \
		openssh-client \
		p7zip-full \
		peass \
		pip \
		proxychains \
		python-is-python3 \
		python3-pwntools \
		python3-pygments \
		python3-venv \
		python3-virtualenv \
		radare2 \
		recon-ng \
		redis-tools \
		rclone \
		rlwrap \
		smbclient \
		smbmap \
		snmp \
		speedtest-cli \
		sqsh \
		sslscan \
		sshpass \
		ssh-audit \
		sublist3r \
		theharvester \
		tmate \
		tree \
		torsocks \
		w3m \
		weechat weechat-plugins weechat-matrix \
		whatweb \
		wipe \
		wpscan \
		wrk \
		zoxide \
	&& /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		bloodhound \
		default-jdk \
		exploitdb \
		gem \
		golang-go \
		npm \
		nodejs \
		php \
		pkg-config \
		ripgrep \
		rust-all \
		ruby \
		x11-apps \
	&& /pkg-install.sh HUGE ghbin SagerNet/sing-box 'linux-amd64.' sing-box \
	&& /pkg-install.sh HUGE ghbin tomnomnom/waybackurls 'linux-amd64-' waybackurls \
	&& /pkg-install.sh HACK ghbin projectdiscovery/uncover 'linux_amd64.zip$' uncover \
	&& /pkg-install.sh HACK ghbin projectdiscovery/httpx 'linux_amd64.zip$' httpx \
	&& /pkg-install.sh HACK ghbin projectdiscovery/nuclei 'linux_amd64.zip$' nuclei \
	&& /pkg-install.sh LARGE ghbin Peltoche/lsd 'lsd_.*_amd64.deb$' \
	&& /pkg-install.sh LARGE ghbin cheat/cheat 'linux-amd64.gz$' cheat \
	&& /pkg-install.sh LARGE ghbin sensepost/gowitness 'linux-amd64$' gowitness \
	&& /pkg-install.sh LARGE bash -c "{ mkdir -p /usr/share/cheatsheets/community \
		&& git clone --depth 1 https://github.com/cheat/cheatsheets.git /usr/share/cheatsheets/community; }" \
	&& /pkg-install.sh LARGE pip install --pre 'scapy[basic]' \
	&& /pkg-install.sh WEB pip install \
		'pelican[Markdown]' \
	&& /pkg-install.sh LARGE pip install \
		git-dumper \
		ipython \
		shodan \
		maigret \
	&& /pkg-install.sh HACK pip install \
		arsenal-cli \
		hashid \
		kerbrute \
		sqlmap \
	&& /pkg-install.sh DEVEL pip install \
		cryptocode \
		colorama \
		PyCryptodome \
	&& /pkg-install.sh LARGE bash -c "{ curl -fsSL https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.0/geonet_0.4.0_amd64.deb -o /tmp/geonet.deb \
		&& dpkg -i /tmp/geonet.deb; }" \
	&& /pkg-install.sh MINI bash -c "{ [[ -f /usr/share/locale/locale.alias ]] && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; }" \
	&& /pkg-install.sh DEVEL bash -c "{ [[ $(uname -m) = "x86_64" ]] && apt-get install -y --no-install-recommends linux-headers-amd64; }" \
	&& { rm -f /tmp/*.deb; true; } \
	&& /pkg-install.sh HACK bash -c "curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xfvz - -C /usr/local/bin" \
	&& echo "DONE."

# Keep the apt/lists in case user does an apt update -y
#RUN rm -rf /var/lib/apt/lists/*

# Do fs-root last (on vmbox it messes with permissions on directories and setup.sh fixes it)
COPY /fs-root/ /
RUN		/setup.sh \
	&& rm -f /setup.sh /pkg-install.sh

CMD ["zsh", "-il"]
