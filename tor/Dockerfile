FROM alpine:edge

RUN apk add --no-cache curl tor bash && \
	(echo -e "\
SocksPort 0.0.0.0:9050\n\
HiddenServiceDir /var/lib/tor/hidden_service/\n\
HiddenServicePort 80 nginx:80\n\
"; cat /etc/tor/torrc.sample) >/etc/tor/torrc && \
	echo "DONE"

EXPOSE 9050

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD curl -s --socks5 127.0.0.1:9050 'https://check.torproject.org/' | grep -qm1 Congratulations

COPY /fs-root/ /
RUN chmod 755 /sf-tor.sh

CMD ["/sf-tor.sh"]
