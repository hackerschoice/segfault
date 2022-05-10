FROM kalilinux/kali-rolling

WORKDIR /root/
RUN apt update -y && \
	apt install -y --no-install-recommends \
		ca-certificates \
		curl
RUN	apt install -y --no-install-recommends \
		gcc \
		git \
		automake \
		patch
RUN apt install -y --no-install-recommends \
		vim \
		binutils \
		dnsutils \
		openssh-client \
		iputils-ping \
		screen \
		tmux \
		socat \
		nmap \
		hexedit \
		iproute2 \
		procps \
		rsync \
		htop \
		gsocket \
		netcat-traditional
RUN apt install -y --no-install-recommends \
		zsh zsh-syntax-highlighting zsh-autosuggestions

COPY /fs-root/ /
COPY setup.sh /
RUN /setup.sh && \
	rm -f /setup.sh

CMD ["zsh", "-il"]