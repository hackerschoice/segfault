FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
	&& wget -O/gs-netcat "https://github.com/hackerschoice/gsocket/releases/latest/download/gs-netcat_linux-$(uname -m)" \
	&& chmod 755 /gs-netcat

COPY sf-gsnc.sh /
