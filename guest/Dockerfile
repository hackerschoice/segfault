# FROM kalilinux/kali-rolling
# FROM kalilinux/kali-bleeding-edge
# 2023-02-19: kali-rolling has packages with dependencies for python <<3.11 but installs python 3.11.1-3
FROM kalilinux/kali-last-release

WORKDIR /root/

# Valid options are:
#   MINI BASE DEVEL NET WEB HACK LARGE HUGE GUI ALL
#   SF_PACKAGES=ALL make     # All
#   SF_PACKAGES=ALLALL make  # All _and_ kali-linux-everything
# Default is "MINI BASE NET" (see pkg-install.sh)
ARG SF_PACKAGES

COPY fs-root/sf/bin/pkg-install.sh /

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
		ed \
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
		unrar \
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
		libsodium-dev \
		libssl-dev \
		ltrace \
		lz4 \
		make \
		musl \
		musl-tools \
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
		iperf \
		iperf3 \
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
		adb \
		apktool \
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
		pwncat \
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
		flatpak \
		fossil \
		fzf \
		gnupg \
		hashcat \
		highlight \
		httpie \
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
		lolcat \
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
		nginx \
		ngrep \
		nikto \
		openssh-client \
		p7zip-full \
		peass \
		pip \
		pipx \
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
		syncthing-relaysrv \
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
		veil
RUN /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		seclists
RUN /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		debootstrap \
		qemu-efi \
		qemu-efi-arm \
		qemu-user \
		qemu-utils \
		u-boot-qemu
RUN /pkg-install.sh ALLALL apt-get install -y kali-linux-everything
## Everything above here should be stable and not modified (or a full rebuild will occur)
#########################################################################################
RUN /pkg-install.sh HUGE bash -c 'mkdir /usr/muslcc; \
	muslinstall() { \
		local n; \
		n="${1}-linux-musl${2}"; \
		echo "[muslCC] Installing ${n}..."; \
		curl -fsSL "https://musl.cc/${n}-cross.tgz" | tar xfz - -C /usr/muslcc || return; \
		ln -s "../muslcc/${n}-cross/bin/${n}-gcc" "/usr/bin/${n}-gcc"; \
		ln -s "${n}-gcc" "/usr/bin/gcc-${1}-linux"; \
		ln -s "${n}-gcc" "/usr/bin/musl-gcc-${1}-linux"; \
	}; \
	muslinstall "aarch64"     ""; \
	muslinstall "arm"         "eabi"; \
	muslinstall "armv7l"      "eabihf"; \
	muslinstall "armv6"       "eabi"; \
	muslinstall "i686"        ""; \
	muslinstall "x86_64"      ""; \
	muslinstall "mips64"      ""; \
	muslinstall "mips64el"    ""; \
	muslinstall "mips"        "sf"; \
	muslinstall "mipsel"      "sf"; \
	muslinstall "powerpc"     ""; \
	muslinstall "powerpcle"   ""; \
	muslinstall "powerpc64"   ""; \
	muslinstall "powerpc64le" ""'
RUN /pkg-install.sh GUI bash -c '{ cd /tmp \
		&& curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
		&& wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg >/dev/null \
		&& wget -qO - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null \
		&& echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" >/etc/apt/sources.list.d/brave-browser-release.list \
		&& echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list \
		&& echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/microsoft.list \
		&& apt-get update; }' \
	&& /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		`###alacritty - Not available in stable release` \
		aqemu \
		awesome \
		brave-browser \
		code \
		evince \
		eterm \
		enlightenment-data \
		fluxbox \
		fonts-noto-color-emoji \
		fonts-symbola \
		geany \
		gimp \
		gnome \
		gnome-terminal \
		kate \
		kitty \
		konsole \
		libreoffice \
		ncurses-term \
		pidgin \
		qemu-system-gui \
		remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret remmina-plugin-exec remmina-plugin-kwallet remmina-plugin-python remmina-plugin-www remmina-plugin-x2go \
		qterminal `### needs RSS 80mb of memory` \
		rxvt-unicode \
		sublime-text \
		syncthing-gtk \
		terminator \
		tigervnc-standalone-server \
		tilix \
		wireshark \
		x11vnc \
		x11-xserver-utils \
		xterm \
		xorg \
		xrdp
RUN /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		`### xpra ` \
		libavformat59 \
		libavif15 \
		libjs-jquery-ui \
		libprocps8 `### Not available in kali-rolling` \
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
		xvfb
# Everything below here will overwrite packages already installed by apt-get.
#############################################################################
RUN /pkg-install.sh GUI bash -c '{ cd /usr/lib \
		&& curl -sf https://download-installer.cdn.mozilla.net/pub/firefox/releases/108.0.1/linux-x86_64/en-US/firefox-108.0.1.tar.bz2 | tar xfvj - \
		&& ln -s /usr/lib/firefox/firefox /usr/bin/firefox; }'
RUN	/pkg-install.sh GUI bash -c '{ cd /tmp \
		`### Use the debian package (not ubuntu) because dpkg does not support .zst compression used in the ubuntu .deb file ` \
		`### Beta releases are at: https://xpra.org/beta/testing/main/binary-amd64/ ` \
		&& rm -f /tmp/*.deb \
		`### && wget http://ftp.de.debian.org/debian/pool/main/p/procps/libprocps8_3.3.17-5_amd64.deb ### NEEDED FOR KALI-ROLLING ONLY` \
		&& wget https://xpra.org/dists/sid/main/binary-amd64/xpra_4.4.3-r0-1_amd64.deb \
		&& wget https://xpra.org/dists/sid/main/binary-amd64/xpra-html5-6.2-r1-1.deb \
		&& dpkg -i *.deb \
		&& rm -f /tmp/*.deb; }'
RUN /pkg-install.sh GUI bash -c '{ true; \
		rm -f /etc/apt/sources.list.d/*.list; \
		apt-get update ; }'
RUN /pkg-install.sh HUGE ghbin SagerNet/sing-box 'linux-amd64.' sing-box \
	&& /pkg-install.sh HACK bin https://api.localxpose.io/api/v2/downloads/loclx-linux-amd64.zip loclx \
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
	&& /pkg-install.sh HACK ghbin tomnomnom/anew 'linux-amd64' anew \
	&& /pkg-install.sh HACK ghbin lc/gau 'linux_amd64.tar.gz$' gau \
	&& /pkg-install.sh LARGE ghbin denisidoro/navi 'x86_64-unknown-linux' navi \
	&& /pkg-install.sh LARGE bash -c '{ GOBIN=/usr/bin go install github.com/subfinder/goaltdns@latest; }' \
	&& /pkg-install.sh LARGE bash -c '{ curl -sf https://gobinaries.com/d3mondev/puredns | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh LARGE bash -c '{ curl -sf https://gobinaries.com/asciimoo/wuzz | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh LARGE bash -c '{ curl -sf https://gobinaries.com/gwen001/github-subdomains | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh LARGE bash -c '{ mkdir -p /usr/share/cheatsheets/community \
		&& git clone --depth 1 https://github.com/cheat/cheatsheets.git /usr/share/cheatsheets/community; }' \
	&& /pkg-install.sh HACK bash -c '{ cd /usr/share/nmap/scripts \
		&& git clone --depth 1 https://github.com/scipag/vulscan; }'
RUN /pkg-install.sh HUGE bash -c '{ cd /tmp \
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
	&& /pkg-install.sh HACK bash -c '{ cd /tmp \
		&& git clone --depth 1 https://github.com/fullhunt/log4j-scan \
		&& cd log4j-scan \
		&& pip install -r requirements.txt \
		&& cp log4j-scan.py /usr/local/bin/log4j-scan; }' \
	&& /pkg-install.sh LARGE pip install \
		discord \
		git-dumper \
		ipython \
		shodan \
		maigret \
	&& /pkg-install.sh HACK pip install \
		arsenal-cli \
		git+https://github.com/vortexau/dnsvalidator \
		h8mail \
		hashid \
		holehe \
		pyTelegramBotAPI \
		git+https://github.com/EntySec/Shreder \
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
### AFter 0.4.3a release
RUN /pkg-install.sh GAMES apt-get install -y --no-install-recommends \
	pacman4console
RUN /pkg-install.sh EMU apt-get install -y --no-install-recommends \
		dosbox \
		fs-uae fs-uae-arcade \
		vice
RUN sed 's/deb-src.*//' -i /etc/apt/sources.list \
	&& apt-get update

# Keep the apt/lists in case user does an apt update -y
#RUN rm -rf /var/lib/apt/lists/*

# Do fs-root last (on vmbox it messes with permissions on directories and setup.sh fixes it)
COPY setup.sh /fs-root/ /
RUN		/setup.sh \
	&& rm -f /setup.sh /pkg-install.sh

CMD ["zsh", "-il"]
