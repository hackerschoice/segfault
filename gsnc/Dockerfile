FROM alpine

RUN apk add --no-cache --upgrade \
	&& apk add --no-cache \
		bash \
	&& wget -O - https://github.com/hackerschoice/binary/raw/main/gsocket/bin/gs-netcat_x86_64-alpine.tar.gz | tar xfvz -

COPY sf-gsnc.sh /
