FROM kalilinux/kali-rolling

WORKDIR /root/
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		ca-certificates \
		curl
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		locales \
		gcc \
		g++ \
		git \
		make \
		build-essential \
		strace \
		ltrace \
		gdb \
		automake \
		byacc \
		flex \
		bison \
		man-db \
		manpages-dev \
		python-is-python3 \
		patch \
		sudo
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		vim \
		binutils \
		whois \
		dnsutils \
		bc \
		openssh-client \
		iputils-ping \
		iputils-tracepath \
		net-tools \
		screen \
		tmux \
		socat \
		nmap \
		irssi \
		hexedit \
		ngrep \
		iproute2 \
		traceroute \
		mtr \
		procps \
		rsync \
		wipe \
		htop \
		dstat \
		gsocket \
		wget \
		proxychains \
		gnupg \
		pip \
		jq \
		less \
		bat \
		duf \
		lynx \
		netcat-traditional
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		golang-go \
		pkg-config
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		x11-apps
RUN	apt update -y && \
	apt install -y --no-install-recommends \
		zsh \
		zsh-syntax-highlighting \
		zsh-autosuggestions
RUN	curl -fsSL https://github.com/Peltoche/lsd/releases/download/0.21.0/lsd_0.21.0_amd64.deb -o /tmp/lsd.dep && \
	dpkg -i /tmp/lsd.dep && \
	rm -f /tmp/lsd.dep && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# Keep the apt/lists in case user does a apt update -y
#RUN rm -rf /var/lib/apt/lists/*

COPY /fs-root/ /
COPY setup.sh /
RUN	/setup.sh && \
	rm -f /setup.sh

CMD ["zsh", "-il"]
