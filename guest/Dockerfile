# FROM kalilinux/kali-rolling
# FROM kalilinux/kali-bleeding-edge
# 2023-02-19: kali-rolling has packages with dependencies for python <<3.11 but installs python 3.11.1-3
FROM kalilinux/kali-last-release
#FROM kalilinux/kali-rolling

WORKDIR /root/

# AARCH64: Some packages are not available for aarch64. In this case we try to
# install the x86_64 versoin for static binaries and skip the package otherwise.

# Valid options are:
#   MINI BASE DEVEL NET WEB HACK LARGE HUGE GUI ALL
#   SF_PACKAGES=ALL make     # All
#   SF_PACKAGES=ALLALL make  # All _and_ kali-linux-everything
# Default is "MINI BASE NET" (see pkg-install.sh)
ARG SF_PACKAGES
ARG GITHUB_TOKEN
ARG BESTEFFORT

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
		gnupg \
		jq \
		less \
		openssh-sftp-server \
		python3-pip \
		screen \
		sharutils \
		sshfs \
		subversion \
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
		cmake \
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
		libev-dev \
		libfreetype6-dev `### ft2build.h missing otherwise` \
		libsodium-dev \
		libssl-dev \
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
# x86_64 only:
RUN /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
		lib32z1 \
		ltrace || { [ $(uname -m) != x86_64 ] && true; }
RUN /pkg-install.sh NET apt-get install -y --no-install-recommends \
		dnsutils \
		ftp \
		iftop \
		iperf \
		iperf3 \
		iputils-tracepath \
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
		oscanner \
		pagekite \
		pwncat \
		python3-shodan \
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
# x86_64 only
RUN /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		oracle-instantclient-sqlplus || { [ $(uname -m) != x86_64 ] && true; }
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
		cython3 \
		dirb \
		dirsearch \
		dnsenum \
		dnsrecon \
		dstat \
		duf \
		elinks \
		emacs \
		emailharvester \
		enum4linux \
		evil-winrm \
		exa \
		exiftool \
		fd-find \
		flatpak \
		fossil \
		fzf \
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
		python3-cheroot \
		python3-full \
		python3-scapy \
		python3-poetry \
		python3-pwntools \
		python3-pygments \
		python3-venv \
		python3-virtualenv \
		python3-ipython \
		python3-all-dev \
		python3-setuptools \
		python-all-dev \
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
# x86_64 only:
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		dotnet-runtime-6.0 \
		eyewitness || { [ $(uname -m) != x86_64 ] && true; }
RUN /pkg-install.sh WEB apt-get install -y --no-install-recommends \
		pelican
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
		rubygems
# x86_64 only
RUN /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		veil || { [ $(uname -m) != x86_64 ] && true; }
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
		&& echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" >/etc/apt/sources.list.d/brave-browser-release.list \
		&& echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list \
		&& echo "deb https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/microsoft.list \
		&& apt-get update; }' \
	&& /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		`###alacritty - Not available in stable release` \
		aqemu \
		awesome \
		brave-browser \
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
# x86_64 only	
RUN /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		code || { [ $(uname -m) != x86_64 ] && true; }
RUN /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		`### xpra ### Using Xpra repo instead` \
		libavformat59 \
		libavif15 \
		libjs-jquery-ui \
		`###libprocps8 ### yanked from Kali` \
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
### 2023-02: xpra has been janked. the non-beta is broken on kali (and also conflicts with libprocps8)
# RUN	/pkg-install.sh GUI bash -c '{ `### only Beta has no conflict with python 3.11.3 and libprocps8` \
# 		&& wget -O "/usr/share/keyrings/xpra-2022.gpg" https://xpra.org/xpra-2022.gpg \
# 		&& wget -O "/etc/apt/sources.list.d/xpra-beta.list" https://xpra.org/repos/bookworm/xpra-beta.list \
# 		&& apt-get update \
# 		&& pkg=("xpra" "xpra-html5") \
# 		&& { [[ $HOSTTYPE != aarch64 ]] && pkg+=("xpra-x11"); true; `### x86_64 only`;  } \
# 		&& apt-get install -y --no-install-recommends "${pkg[@]}" \
# 		&& rm -f /var/lib/apt/lists/xpra*; }'
### 2023-06: https://github.com/Xpra-org/xpra/issues/3863
RUN	/pkg-install.sh GUI bash -c '{ : \
		&& wget -O "/usr/share/keyrings/xpra.asc" https://xpra.org/xpra-2023.asc \
		&& wget -O "/etc/apt/sources.list.d/xpra-beta.sources" https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/bookworm/xpra-beta.sources \
		&& apt-get update \
		&& pkg=("xpra" "xpra-html5") \
		&& { [[ $HOSTTYPE != aarch64 ]] && pkg+=("xpra-x11"); true; `### x86_64 only`;  } \
		&& apt-get install -y --no-install-recommends "${pkg[@]}" \
		&& rm -f /var/lib/apt/lists/xpra*; }'
### x86_64 only
RUN /pkg-install.sh GUI bash -c '{ [[ $HOSTTYPE != x86_64 ]] && exit 0; cd /usr/lib \
		&& curl -sf https://download-installer.cdn.mozilla.net/pub/firefox/releases/108.0.1/linux-x86_64/en-US/firefox-108.0.1.tar.bz2 | tar xfvj - \
		&& ln -s /usr/lib/firefox/firefox /usr/bin/firefox; }'
RUN /pkg-install.sh GUI bash -c '{ true; \
		rm -f /etc/apt/sources.list.d/*.list; \
		apt-get update ; }'
RUN /pkg-install.sh    HUGE ghbin SagerNet/sing-box 'linux-%arch:x86_64=amd64:aarch64=arm64%.' sing-box \
	&& /pkg-install.sh HACK bin 'https://api.localxpose.io/api/v2/downloads/loclx-linux-%arch:x86_64=amd64:aarch64=arm64%.zip' loclx \
	&& /pkg-install.sh HACK bin 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-%arch:x86_64=amd64:aarch64=arm64%.tgz' ngrok \
	&& /pkg-install.sh HUGE ghbin tomnomnom/waybackurls 'linux-amd64-' waybackurls \                            
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest; }' \
	&& /pkg-install.sh HACK ghbin projectdiscovery/httpx      'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    httpx \
	&& /pkg-install.sh HACK ghbin projectdiscovery/katana     'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    katana \
	&& /pkg-install.sh HACK ghbin projectdiscovery/naabu      'linux_amd64.zip$'                                naabu      `### x86_64 only` \
	&& /pkg-install.sh HACK ghbin projectdiscovery/nuclei     'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    nuclei \
	&& /pkg-install.sh HACK ghbin projectdiscovery/pdtm       'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    pdtm \
	&& /pkg-install.sh HACK ghbin projectdiscovery/proxify    'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    proxify \
	&& /pkg-install.sh HACK ghbin projectdiscovery/shuffledns '_linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'   shuffledns \
	&& /pkg-install.sh HACK ghbin projectdiscovery/subfinder  'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    subfinder \
	&& /pkg-install.sh HACK ghbin projectdiscovery/tlsx       'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    tlsx \
	&& /pkg-install.sh HACK ghbin projectdiscovery/uncover    'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$'    uncover \
	&& /pkg-install.sh HACK ghbin s0md3v/smap                 'linux_%arch:x86_64=amd64:aarch64=arm64%.tar.xz$' smap
RUN /pkg-install.sh    LARGE ghbin Peltoche/lsd 'lsd_.*_%arch:x86_64=amd64:aarch64=arm64%.deb$' \
	&& /pkg-install.sh LARGE ghbin cloudflare/cloudflared 'linux-%arch:x86_64=amd64:aarch64=arm64%.deb$' \
	&& /pkg-install.sh LARGE ghbin filebrowser/filebrowser '^linux-%arch:x86_64=amd64:aarch64=arm64%-filebrowser.tar.gz$' filebrowser \
	&& /pkg-install.sh LARGE ghbin cheat/cheat 'linux-%arch:x86_64=amd64:aarch64=arm64%.gz$' cheat \
	&& /pkg-install.sh LARGE ghbin sensepost/gowitness 'linux-%arch:x86_64=amd64:aarch64=arm64%$' gowitness \
	&& /pkg-install.sh LARGE ghbin t3rm1n4l/megacmd 'linux_%arch:x86_64=amd64:aarch64=arm64%.zip$' megacmd \
	&& /pkg-install.sh HACK ghbin ropnop/kerbrute 'linux_amd64$' kerbrute    `# x86_64 only` \
	&& /pkg-install.sh HACK bash -c '{ git clone --depth 1 https://github.com/hmgle/graftcp.git \
		&& make -C graftcp install; }' \
	&& /pkg-install.sh HACK ghbin tomnomnom/anew 'linux-amd64' anew          `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin lc/gau 'linux_amd64.tar.gz$' gau           `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin praetorian-inc/fingerprintx 'linux_%arch:x86_64=amd64:aarch64=arm64%.tar.gz$' fingerprintx \
	&& /pkg-install.sh HACK ghbin dwisiswant0/ppfuzz '-%arch%-unknown.*tar.gz' ppfuzz \
	&& /pkg-install.sh HACK ghbin Edu4rdSHL/unimap  'unimap-%arch:x86_64=linux:aarch64=aarch64%' unimap \
	&& /pkg-install.sh LARGE ghbin denisidoro/navi '%arch%-unknown-linux' navi \
	&& /pkg-install.sh LARGE ghbin d3mondev/puredns 'inux-%arch:x86_64=amd64:aarch64=arm64%' puredns \
	&& /pkg-install.sh LARGE bash -c '{ GOBIN=/usr/bin go install github.com/subfinder/goaltdns@latest; }' \
	&& /pkg-install.sh LARGE bash -c '{ curl -sf https://gobinaries.com/asciimoo/wuzz | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh LARGE bash -c '{ curl -sf https://gobinaries.com/gwen001/github-subdomains | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh LARGE bash -c '{ mkdir -p /usr/share/cheatsheets/community \
		&& git clone --depth 1 https://github.com/cheat/cheatsheets.git /usr/share/cheatsheets/community; }' \
	&& /pkg-install.sh HACK bash -c '{ cd /usr/share/nmap/scripts \
		&& git clone --depth 1 https://github.com/scipag/vulscan; }'
### x86_64 only
RUN /pkg-install.sh HUGE bash -c '{ [[ $HOSTTYPE != x86_64 ]] && exit 0; cd /usr/share \
		&& git clone --depth 1 https://github.com/pwndbg/pwndbg \
		&& cd pwndbg \
		&& apt-get install -y --no-install-recommends python3-dev python3-setuptools libglib2.0-dev libc6-dbg  \
		&& ./setup.sh \
		&& echo "source /usr/share/pwndbg/gdbinit.py" >>/etc/gdb/gdbinit \
		&& mkdir -p /usr/src/glibc \
		&& cd /usr/src/glibc \
		&& apt-src install glibc \
		&& echo "directory \$cdir:\$cwd:$(find /usr/src/glibc -maxdepth 1 -type d | tail -n1)" >>/etc/gdb/gdbinit \
		&& { dpkg --force-architecture --remove-architecture i386; \
			rm -f /var/lib/apt/lists/*-i386*; apt-get update; } \
		&& echo DONE; }'
RUN /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		bloodhound.py \
		`# python3-certipy CONFLICT with kali certipy4.0.1` \
		python3-colorama \
		crackmapexec \
		python3-avahi \
		python3-dnspython \
		hashid \
		python3-netaddr \
		python3-pycryptodome \
		python3-pyinotify \
		python3-requests \
		sqlmap \
		python3-termcolor \
		python3-tldextract \
		python3-urllib3 \
		python3-zeroconf \
	&& /pkg-install.sh HACK bin https://raw.githubusercontent.com/fullhunt/log4j-scan/master/log4j-scan.py log4j-scan
RUN /pkg-install.sh HACK apt-get install -y --no-install-recommends \
		python3-aiohttp \
		python3-discord
RUN /pkg-install.sh    HACK pipx install aort \
	&& /pkg-install.sh HACK pipx install arsenal-cli \
	&& /pkg-install.sh HACK pipx install bbrf \
	&& /pkg-install.sh HACK pipx install git+https://github.com/vortexau/dnsvalidator \
	&& /pkg-install.sh HACK pipx install git-dumper \
	&& /pkg-install.sh HACK pipx install git+https://github.com/r0oth3x49/ghauri \
	&& /pkg-install.sh HACK pipx install greynoise \
	&& /pkg-install.sh HACK pipx install h8mail \
	&& /pkg-install.sh HACK pipx install holehe \
	&& /pkg-install.sh HACK pipx install git+https://github.com/codingo/Interlace \
	&& /pkg-install.sh HACK pipx install git+https://github.com/soxoj/maigret `### 2023-03-07 pipx repo fails on aiohttp/longintrepr.h` \
	&& /pkg-install.sh HACK pipx install raccoon-scanner \
	&& /pkg-install.sh HACK pipx install git+https://github.com/EntySec/Shreder \
	&& /pkg-install.sh HACK pipx install userefuzz \
	&& /pkg-install.sh HACK pipx install webtech \
	&& /pkg-install.sh DEVEL pipx install dulwich \
	&& /pkg-install.sh DEVEL pipx install names
RUN /pkg-install.sh WEB bash -c '{ apt-get remove -y pelican; true; }' \
	&& /pkg-install.sh WEB pipx install 'grip' \
	&& /pkg-install.sh WEB pipx install 'pelican[Markdown]' `### apt/pelican causes missing /onion/theme directory` \
	&& /pkg-install.sh WEB pipx install 'tiny-http-server'
RUN /pkg-install.sh DEVEL pip install --break-system-packages \
		cryptocode \
		ipaddress \
		pyTelegramBotAPI \
		tgcrypto \
		wsgidav
RUN /pkg-install.sh    LARGE pipx install gdown \
	&& /pkg-install.sh LARGE pipx install udocker
RUN /pkg-install.sh LARGE bin 'https://gitlab.com/api/v4/projects/32089582/packages/generic/geonet-rs/0.4.3/geonet_0.4.3_%arch:x86_64=amd64:DEFAULT=SKIP%.deb'    `# x86_64 only` \
	&& /pkg-install.sh MINI bash -c "{ [[ -f /usr/share/locale/locale.alias ]] && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; }" \
	&& /pkg-install.sh DEVEL bash -c '{ arch=amd64; [[ $HOSTTYPE == "aarch64" ]] && arch=arm64; apt-get install -y --no-install-recommends linux-headers-${arch}; }'
### After 0.4.3a release
RUN /pkg-install.sh GAMES apt-get install -y --no-install-recommends \
		pacman4console
RUN /pkg-install.sh EMU apt-get install -y --no-install-recommends \
		dosbox \
		fs-uae fs-uae-arcade \
		vice
RUN /pkg-install.sh DEVEL apt-get install -y --no-install-recommends \
		clojure \
		leiningen
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		cron \
		cups-client \
		byobu \
		fish \
		krb5-user \
		krb5-config \	
		parallel \
		sshuttle
RUN /pkg-install.sh HUGE apt-get install -y --no-install-recommends \
		gopls \
		golang-golang-x-tools \
		gobjc++-mingw-w64-i686-posix gobjc++-mingw-w64-i686-win32 gobjc-mingw-w64-i686-posix gobjc-mingw-w64-i686-win32 \
		maven \
		rust-src
RUN /pkg-install.sh HACK ghbin shadow1ng/fscan 'fscan_%arch:x86_64=amd64:aarch64=arm64%$' fscan \
	&& /pkg-install.sh HACK ghbin 'theaog/spirit' 'spirit%arch:x86_64=:DEFAULT=SKIP%.tgz$' spirit   `# x86_64 only, spirit-arm bad` \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/tomnomnom/gf@latest \
		&& mkdir -p /usr/share/gf \
		&& svn export https://github.com/tomnomnom/gf/trunk /tmp/gf \
		&& mv /tmp/gf/examples/*.json /usr/share/gf \
		&& mv /tmp/gf/gf-completion.* /usr/share/gf \
		&& rm -rf /tmp/gf \
		&& svn export https://github.com/1ndianl33t/Gf-Patterns/trunk/ /tmp/gf \
		&& mv /tmp/gf/*.json /usr/share/gf; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/tomnomnom/hacks/inscope@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/Emoe/kxss@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/Josue87/analyticsrelationships@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/Josue87/gotator@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/Josue87/roboxtractor@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/six2dez/ipcdn@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ git clone --depth 1 https://github.com/ameenmaali/urldedupe.git \
		&& cd urldedupe \
		&& cmake . \
		&& make \
		&& cp urldedupe /usr/bin; }' \
	&& /pkg-install.sh HACK bash -c '{ svn export https://github.com/urbanadventurer/username-anarchy/trunk /opt/username-anarchy; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/damit5/gitdorks_go@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/trickest/dsieve@master; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/trickest/enumerepo@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/lobuhi/byp4xx@latest; }' \
	&& /pkg-install.sh HACK bash -c '{ GOBIN=/usr/bin go install github.com/Hackmanit/Web-Cache-Vulnerability-Scanner@latest && ln -s Web-Cache-Vulnerability-Scanner /usr/bin/wcvs; }' \
	&& /pkg-install.sh HACK ghbin tomnomnom/qsreplace         'linux-amd64'                                qsreplace `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin tomnomnom/unfurl            'linux-amd64'                                unfurl    `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin tomnomnom/gron              'linux-%arch:x86_64=amd64:aarch64=arm64%-'   gron \
	&& /pkg-install.sh HACK ghbin tomnomnom/meg               'linux-amd64-'                               meg       `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin projectdiscovery/alterx     '_linux_%arch:x86_64=amd64:aarch64=arm64%'   alterx \
	&& /pkg-install.sh HACK ghbin projectdiscovery/notify     'linux_%arch:x86_64=amd64:aarch64=arm64%'    notify \
	&& /pkg-install.sh HACK ghbin projectdiscovery/interactsh 'linux_%arch:x86_64=amd64:aarch64=arm64%'    interactsh-client \
	&& /pkg-install.sh HACK ghbin projectdiscovery/mapcidr    'linux_%arch:x86_64=amd64:aarch64=arm64%'    mapcidr \
	&& /pkg-install.sh HACK ghbin glebarez/cero               'linux-amd64'                                cero      `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin dwisiswant0/crlfuzz         'inux_%arch:x86_64=amd64:aarch64=arm64%'     crlfuzz \
	&& /pkg-install.sh HACK ghbin hahwul/dalfox               'inux_%arch:x86_64=amd64:aarch64=arm64%'     dalfox \
	&& /pkg-install.sh HACK ghbin pwnesia/dnstake             'linux_%arch:x86_64=amd64:aarch64=arm64%'    dnstake \
	&& /pkg-install.sh HACK ghbin KathanP19/Gxss              'inux_x86_64'                                Gxss      `# x86_64 only` \
	&& /pkg-install.sh HACK ghbin qsocket/qs-netcat           'linux_%arch:x86_64=amd64:aarch64=arm64%'    qs-netcat \
	&& /pkg-install.sh HACK ghbin shenwei356/rush             'linux_%arch:x86_64=amd64:aarch64=arm64%'    rush \
	&& /pkg-install.sh HACK ghbin lc/subjs                    'linux_amd64'                                subjs     `# x86_64 only` \
	&& /pkg-install.sh HACK bash -c '{ curl -sf https://gobinaries.com/gwen001/gitlab-subdomains | PREFIX=/usr/bin sh; }' \
	&& /pkg-install.sh HACK bash -c '{ curl -sf https://gobinaries.com/gwen001/github-endpoints | PREFIX=/usr/bin sh; }'
RUN /pkg-install.sh GUI apt-get install -y --no-install-recommends \
		i3 \
		jupyter \
		pavucontrol \
		pulseaudio \
		tigervnc-tools \
	&& /pkg-install.sh GUI npm install -g carbonyl
RUN /pkg-install.sh WEB apt-get install -y --no-install-recommends \
		libnginx-mod-http-auth-pam \
		libnginx-mod-http-brotli-filter \
		libnginx-mod-http-brotli-static \
		libnginx-mod-http-cache-purge \
		libnginx-mod-http-dav-ext \
		libnginx-mod-http-echo \
		libnginx-mod-http-fancyindex \
		libnginx-mod-http-geoip \
		libnginx-mod-http-geoip2 \
		libnginx-mod-http-headers-more-filter \
		libnginx-mod-http-image-filter \
		libnginx-mod-http-js \
		libnginx-mod-http-lua \
		libnginx-mod-http-memc \
		libnginx-mod-http-modsecurity \
		libnginx-mod-http-ndk \
		libnginx-mod-http-ndk-dev \
		libnginx-mod-http-perl \
		libnginx-mod-http-set-misc \
		libnginx-mod-http-srcache-filter \
		libnginx-mod-http-subs-filter \
		libnginx-mod-http-uploadprogress \
		libnginx-mod-http-upstream-fair \
		libnginx-mod-http-xslt-filter \
		libnginx-mod-mail \
		libnginx-mod-nchan \
		libnginx-mod-rtmp \
		libnginx-mod-stream \
		libnginx-mod-stream-geoip \
		libnginx-mod-stream-geoip2 \
		libnginx-mod-stream-js \
		njs
RUN /pkg-install.sh DEV apt-get install -y --no-install-recommends \
		ninja-build \
		repo
# Android build tools:
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		aria2 \
		buildtorrent \
		caddy \
		ccache \
		expat \
		evilginx2 \
		ffmpeg \
		git-lfs \
		icecream icecream-sundae icecc icecc-monitor \
		lftp \
		libmpc-dev libmpfr-dev libncurses-dev libsdl1.2-dev \
		'^lzma.*' '^liblz4-.*' '^liblzma.*' \
		libfdk-aac2 libdav1d-dev libvorbis-dev libopus-dev libmp3lame-dev libfdk-aac-dev libx264-dev libx265-dev libxvidcore-dev libvpx-dev libspeex-dev libsox-dev libsoxr-dev \
		libxml-simple-perl libswitch-perl \
		lzip \
		lzop \
		magic-wormhole \
		mediainfo \
		ncftp \
		patchelf \
		pngcrush \
		pngquant \
		re2c \
		schedtool \
		'softether-*' \
		sysbench \
		texinfo \
		yt-dlp \
	&& /pkg-install.sh LARGE bash -c '{ apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys B5A08F01796E7F521861B449372D1FF271F2DD50 \
		&& echo "deb http://deb.ooni.org/ unstable main" | tee /etc/apt/sources.list.d/ooniprobe.list \
		&& apt-get update \
		&& apt-get install -y --no-install-recommends ooniprobe-cli \
		&& rm /etc/apt/sources.list.d/ooniprobe.list \
		&& apt-get update; }' \
	&& /pkg-install.sh LARGE ghbin zellij-org/zellij '%arch%.*linux.*tar.gz$' zellij \
	&& /pkg-install.sh LARGE ghbin jkfran/killport '%arch%-linux' killport
# x86_64 only	
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		g++-multilib \
		gcc-multilib \
		lib32ncurses-dev lib32z1-dev || { [ $(uname -m) != x86_64 ] && true; }
RUN /pkg-install.sh    HACK ghbin wader/fq '_linux_%arch:x86_64=amd64:aarch64=arm64%' fq \
	&& /pkg-install.sh HACK bin https://raw.githubusercontent.com/trustedsec/hardcidr/master/hardCIDR.sh hardcidr \
	&& /pkg-install.sh HACK ghbin hahwul/dalfox  '_linux_%arch:x86_64=amd64:aarch64=arm64%' dalfox
RUN /pkg-install.sh NET bin https://github.com/hackerschoice/binary/raw/main/gsocket/latest/gsocket_latest_all.deb   `# x86_64 only` \
	&& /pkg-install.sh NET ghbin shadowsocks/shadowsocks-rust '%arch%.*linux.musl.tar.xz$' \
	&& /pkg-install.sh NET ghbin ginuerzh/gost  'linux-%arch:x86_64=amd64:aarch64=armv8%.*gz$' gost \
	&& /pkg-install.sh NET ghbin tulir/gomuks 'linux-%arch:x86_64=amd64:aarch64=arm64%' gomuks \
	&& /pkg-install.sh NET ghbin maxmind/mmdbinspect 'linux_amd64.tar.gz$' mmdbinspect       `# x86_64 only` \
	&& /pkg-install.sh NET ghbin KaranGauswami/socks-to-http-proxy 'sthp-linux' sthp         `# x86_64 only` \
	&& /pkg-install.sh NET ghbin schollz/croc 'Linux-%arch:x86_64=64bit:aarch64=ARM64%.deb' \
	&& /pkg-install.sh NET ghbin vi/websocat '%arch%.*linux-musl' websocat \
	&& /pkg-install.sh NET ghbin ViRb3/wgcf  'linux_%arch:x86_64=amd64:aarch64=arm64%$' wgcf \
	&& /pkg-install.sh NET apt-get install -y --no-install-recommends \
		hping3 \
		ipcalc ipcalc-ng \
		microsocks \
		tinyproxy
# gophish vommits user-data into the system-wide install directory. Unix
# doesnt work like this. Impossible to install system-wide. Instead each user
# shall check out his own. No system-wide install for gophish. Sorry. Someone
# give gophish a helping hand or send them a Unix manual...
RUN /pkg-install.sh LARGE ghdir gophish/gophish 'linux-64bit.zip$' /usr/gophish             `# x86_64 only` \
		&& bash -c '{ [[ ! -d /usr/gophish ]] && exit 0; chmod 755 /usr/gophish/gophish \
			&& echo -e "#! /bin/bash\ncd /usr/gophish && exec ./gophish \"\$@\"" >/usr/bin/gophish \
			&& chmod 755 /usr/bin/gophish; }'
RUN /pkg-install.sh HUGE pipx install bbot
RUN /pkg-install.sh HUGE npm install -g wscat
RUN /pkg-install.sh HUGE bash -c 'mkdir -p /usr/share/wordlists; curl -fsSL https://crackstation.net/files/crackstation-human-only.txt.gz | gunzip >/usr/share/wordlists/crackstation-human-only.txt'
RUN /pkg-install.sh LARGE apt-get install -y --no-install-recommends \
		bpytop \
		btop
RUN sed 's/deb-src.*//' -i /etc/apt/sources.list \
	&& apt-get autoremove -y \
	&& apt-get update

# Keep the apt/lists in case user does an apt update -y
#RUN rm -rf /var/lib/apt/lists/*

# Do fs-root last (on vmbox it messes with permissions on directories and setup.sh fixes it)
COPY setup.sh /fs-root/ /
RUN		/setup.sh \
	&& rm -f /setup.sh /pkg-install.sh

CMD ["zsh", "-il"]
