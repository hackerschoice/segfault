
FROM sf-base

ARG VER="2.1.14"

RUN bash -c '{ true \
              && ARCH=$(uname -m) \
		&& { [ "$ARCH" = "aarch64" ] && ARCH=arm64; true; } \
              && curl -SsfL https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/${VER:?}/dnscrypt-proxy-linux_${ARCH:?}-${VER:?}.tar.gz | tar xfz - --transform="flags=r;s|.*/||" --no-anchored  -C "/usr/sbin" --wildcards "dnscrypt-proxy"  \
              && true; }' \
       && true

# COPY config /config

CMD ["bash", "-il"]

