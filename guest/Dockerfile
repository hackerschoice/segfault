FROM kalilinux/kali-rolling

WORKDIR /root/
RUN apt update -y && \
	apt install -y --no-install-recommends \
		ca-certificates \
		curl
RUN	apt install -y --no-install-recommends \
		gcc \
		g++ \
		git \
		make \
		build-essential \
		automake \
		byacc \
		flex \
		bison \
		man-db \
		manpages-dev \
		python-is-python3 \
		patch
RUN apt install -y --no-install-recommends \
		vim \
		binutils \
		dnsutils \
		openssh-client \
		iputils-ping \
		iputils-tracepath \
		net-tools \
		screen \
		tmux \
		socat \
		nmap \
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
		netcat-traditional
RUN apt install -y --no-install-recommends \
		zsh zsh-syntax-highlighting zsh-autosuggestions

COPY /fs-root/ /
COPY setup.sh /
RUN /setup.sh && \
	rm -f /setup.sh

CMD ["zsh", "-il"]
