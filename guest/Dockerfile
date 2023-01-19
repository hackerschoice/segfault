FROM kalilinux/kali-rolling

WORKDIR /root/

# Valid options are:
#   MINI BASE DEVEL NET WEB HACK LARGE HUGE GUI ALL
#   SF_PACKAGES=ALL make
# Default is "MINI BASE NET" (see pkg-install.sh)
ARG SF_PACKAGES

COPY setup.sh fs-root/sf/bin/pkg-install.sh /

RUN	sed 's/^deb \(.*\)/deb \1\ndeb-src \1/g' -i /etc/apt/sources.list \
	&& apt-get update -y \
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
		zsh-syntax-highlighting
RUN /pkg-install.sh BASE apt-get install -y --no-install-recommends \
		apt-src \
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
		wget \
		xxd
RUN /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
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
		lib32z1 \
		libc-devtools \
		libevent-dev \
		libev-dev \
		libssl-dev \
		ltrace \
		lz4 \
		make \
		patch \
		perl-tk \
		pv \
		sbcl \
		source-highlight \
		strace \
		wdiff \
		whiptail \
		xterm
RUN /pkg-install.sh NET apt-get install -y --no-install-recommends \
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
		whois
RUN /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		assetfinder \
		crackmapexec \
		dnsmap \
		dnsx \
		ffuf \
		hydra \
		gobuster \
		impacket-scripts \
		irssi \
		lshw \
		massdns \
		masscan \
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
		upx \
		webshells \
		weevely
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		aha \
		altdns \
		amass \
		apache2-utils \
		apt-file \
		apt-utils \
		backdoor-factory \
		bat \
		clang \
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
		fossil \
		fzf \
		gnupg \
		hashcat \
		highlight \
		htop \
		libcurl4-openssl-dev \
		libdbus-glib-1-dev \
		libedit2 \
		libgcc-12-dev \
		libstdc++-12-dev \
		libicu-dev \
		libxml2-dev \
		libxml2-utils \
		libz3-dev \
		ldap-utils \
		ldapscripts \
		jsbeautifier \
		joe \
		john \
		lsof \
		lynx \
		mc \
		mercurial \
		mg \
		mtr \
		mongodb-server-core \
		mono-mcs \
		mono-devel \
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
		python2-minimal \
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
		syncthing \
		theharvester \
		tmate \
		tree \
		torsocks \
		urlcrazy \
		uvicorn \
		w3m \
		wafw00f \
		weechat weechat-plugins weechat-matrix \
		whatweb \
		wipe \
		wpscan \
		wrk \
		xdg-utils \
		xfce4 xfce4-goodies dbus-x11 x11-xserver-utils \
		xmlstarlet \
		xsltproc \
		xvfb \
		zlib1g-dev \
		zoxide
RUN /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		bloodhound \
		chromium \
		cutycapt \
		default-jdk \
		exploitdb \
		gem \
		golang \
		npm \
		nodejs \
		php \
		pkg-config \
		ripgrep \
		rust-all \
		ruby \
		rubygems \
		veil \
		x11-apps
RUN /pkg-install.sh GUI bash -c '{ cd /tmp \
		&& curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
		&& wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg >/dev/null \
		&& echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" >/etc/apt/sources.list.d/brave-browser-release.list \
		&& echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list \
		&& apt-get update; }' \
	&& /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		awesome \
		brave-browser \
		eterm \
		enlightenment-data \
		fluxbox \
		geany \
		remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret remmina-plugin-exec remmina-plugin-kwallet remmina-plugin-python remmina-plugin-www remmina-plugin-x2go \
		`### qterminal # needs RSS 80mb of memory` \
		tigervnc-standalone-server \
		sublime-text \
		wireshark \
		x11vnc \
		x11-xserver-utils \
		xterm \
		xorg \
		xrdp \
	&& /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		`### xpar ` \
		libavformat59 \
		libavif15 \
		libjs-jquery-ui \
		`### DISABLED. NO LONGER PART OF KALI: libprocps8 ` \
		libqrencode4 \
		libxres1 \
		libxtst6 \
		libswscale6 \
		libturbojpeg0 \
		gir1.2-gtk-3.0 \
		python3-cairo \
		python3-gi \
		python3-gi-cairo \
		python3-opengl \
		python3-pil \
		python3-rencode \
		xserver-xorg-video-dummy \
		xvfb \
	&& /pkg-install.sh GUI bash -c '{ cd /usr/lib \
		&& curl  https://download-installer.cdn.mozilla.net/pub/firefox/releases/108.0.1/linux-x86_64/en-US/firefox-108.0.1.tar.bz2 | tar xfvj - \
		&& ln -s /usr/lib/firefox/firefox /usr/bin/firefox; }' \
	&& /pkg-install.sh GUI-DISABLED bash -c '{ cd /tmp \
		`### Use the debian package (not ubuntu) because dpkg does not support .zst compression used in the ubuntu .deb file ` \
		&& wget http://ftp.de.debian.org/debian/pool/main/p/procps/libprocps8_3.3.17-5_amd64.deb \
		&& wget https://xpra.org/dists/sid/main/binary-amd64/xpra_4.4.3-r0-1_amd64.deb \
		&& wget https://xpra.org/dists/sid/main/binary-amd64/xpra-html5-6.2-r1-1.deb \
		&& dpkg -i libprocps*.deb xpra*.deb \
		&& rm -f /tmp/xpra*.deb; }' \
	&& /pkg-install.sh GUI bash -c '{ true; \
		rm -f /etc/apt/sources.list.d/brave-browser-release.list; \
		rm -f /etc/apt/sources.list.d/sublime-text.list; \
		apt-get update ; }'
RUN /pkg-install.sh HUGE ghbin SagerNet/sing-box 'linux-amd64.' sing-box \
	&& /pkg-install.sh HUGE ghbin tomnomnom/waybackurls 'linux-amd64-' waybackurls \
	&& /pkg-install.sh HACK ghbin projectdiscovery/uncover 'linux_amd64.zip$' uncover \
	&& /pkg-install.sh HACK ghbin projectdiscovery/httpx 'linux_amd64.zip$' httpx \
	&& /pkg-install.sh HACK ghbin projectdiscovery/nuclei 'linux_amd64.zip$' nuclei \
	&& /pkg-install.sh HACK ghbin projectdiscovery/subfinder 'linux_amd64.zip$' subfinder \
	&& /pkg-install.sh HACK ghbin projectdiscovery/naabu 'linux_amd64.zip$' naabu \
	&& /pkg-install.sh HACK ghbin projectdiscovery/proxify 'linux_amd64.zip$' proxify \
	&& /pkg-install.sh HACK ghbin projectdiscovery/katana 'linux_amd64.zip$' katana \
	&& /pkg-install.sh HACK ghbin projectdiscovery/tlsx 'linux_amd64.zip$' tlsx \
	&& /pkg-install.sh HACK ghbin s0md3v/smap 'linux_amd64.tar.xz$' smap \
	&& /pkg-install.sh LARGE ghbin Peltoche/lsd 'lsd_.*_amd64.deb$' \
	&& /pkg-install.sh LARGE ghbin cloudflare/cloudflared 'linux-amd64.deb$' \
	&& /pkg-install.sh LARGE ghbin filebrowser/filebrowser '^linux-amd64-filebrowser.tar.gz$' filebrowser \
	&& /pkg-install.sh LARGE ghbin cheat/cheat 'linux-amd64.gz$' cheat \
	&& /pkg-install.sh LARGE ghbin sensepost/gowitness 'linux-amd64$' gowitness \
	&& /pkg-install.sh LARGE ghbin t3rm1n4l/megacmd 'linux_amd64.zip$' megacmd \
	&& /pkg-install.sh HACK ghbin ropnop/kerbrute 'linux_amd64$' kerbrute \
	&& /pkg-install.sh HACK ghbin hmgle/graftcp '_amd64.deb$' \
	&& /pkg-install.sh LARGE ghbin denisidoro/navi 'x86_64-unknown-linux' navi \
	&& /pkg-install.sh LARGE bash -c '{ GOBIN=/usr/bin go install github.com/d3mondev/puredns/v2@latest; }' \
	&& /pkg-install.sh LARGE bash -c '{ mkdir -p /usr/share/cheatsheets/community \
		&& git clone --depth 1 https://github.com/cheat/cheatsheets.git /usr/share/cheatsheets/community; }' \
	&& /pkg-install.sh HACK bash -c '{ cd /usr/share/nmap/scripts \
		&& git clone --depth 1 https://github.com/scipag/vulscan; } ' \
	&& /pkg-install.sh HUGE bash -c '{ cd /tmp \
		&& git clone --depth 1 https://github.com/pwndbg/pwndbg \
		&& cd pwndbg \
		&& apt-get install -y --no-install-recommends python3-dev python3-setuptools libglib2.0-dev libc6-dbg  \
		&& { dpkg --add-architecture i386 \
			&& apt-get update \
			&& apt-get install -y --no-install-recommends libc6-dbg:i386 \
			&& dpkg --force-architecture --remove-architecture i386 \
			&& rm -f /var/lib/apt/lists/*-i386_Packages.lz4; } \
		&& pip install -Ur requirements.txt \
		&& cd .. \
		&& mv pwndbg /usr/share \
		&& echo "source /usr/share/pwndbg/gdbinit.py" >>/etc/gdb/gdbinit \
		&& mkdir -p /usr/src/glibc \
		&& cd /usr/src/glibc \
		&& apt-src install glibc \
		&& echo "directory \$cdir:\$cwd:$(find /usr/src/glibc -maxdepth 1 -type d | tail -n1)" >>/etc/gdb/gdbinit \
		&& echo DONE; }'
RUN /pkg-install.sh LARGE pip install --pre 'scapy[basic]' \
	&& /pkg-install.sh WEB pip install \
		'pelican[Markdown]' \
	&& /pkg-install.sh LARGE pip install \
		discord \
		git-dumper \
		ipython \
		shodan \
		maigret \
	&& /pkg-install.sh HACK pip install \
		arsenal-cli \
		h8mail \
		hashid \
		pyTelegramBotAPI \
		sqlmap \
		tgcrypto \
		webtech \
	&& /pkg-install.sh DEVEL pip install \
		cryptocode \
		colorama \
		cython \
		dnspython \
		dulwich \
		ipaddress \
		names \
		netaddr \
		PyCryptodome \
		tgcrypto \
		tldextract \
		urllib3
RUN /pkg-install.sh LARGE bash -c "{ curl -fsSL https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.0/geonet_0.4.0_amd64.deb -o /tmp/geonet.deb \
		&& dpkg -i /tmp/geonet.deb; }" \
	&& /pkg-install.sh MINI bash -c "{ [[ -f /usr/share/locale/locale.alias ]] && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; }" \
	&& /pkg-install.sh DEVEL bash -c '{ [[ $(uname -m) = "x86_64" ]] && apt-get install -y --no-install-recommends linux-headers-amd64; }' \
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
