FROM alpine

COPY /fs-root/ /

RUN apk add --no-cache curl tor bash iptables openssl coreutils util-linux && \
	(echo -e "\
SocksPort 0.0.0.0:9050\n\
HiddenServiceDir /var/lib/tor/hidden/service-80/\n\
HiddenServicePort 80 172.20.1.80:80\n\
HiddenServiceDir /var/lib/tor/hidden/service-22/\n\
HiddenServicePort 22 172.22.0.22:22\n\
VirtualAddrNetworkIPv4 10.111.0.0/16\n\
AutomapHostsOnResolve 1\n\
TransPort 0.0.0.0:9040\n\
DNSPort 0.0.0.0:5353\n\
"; cat /etc/tor/torrc.sample) >/etc/tor/torrc \
	&& echo "DONE" \
	&& chmod 755 /sf-tor.sh

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD curl -s --socks5 127.0.0.1:9050 'https://check.torproject.org/' | grep -qm1 Congratulations

CMD ["/sf-tor.sh"]
