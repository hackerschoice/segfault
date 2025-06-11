
# sf-master
FROM sf-base
COPY init-master.sh ready-lg.sh teardown-lg.sh finish-bootup.sh dict.txt /
COPY /cgi-bin/ /cgi-bin

RUN bash -c '{ true \
              && cp /usr/bin/nsenter /usr/bin/nsenter.u1000 \
              && chown 1000:1000 /usr/bin/nsenter.u1000 \
              && chmod ug+s /usr/bin/nsenter.u1000 \
              && setcap "CAP_SYS_ADMIN+eip" /usr/bin/nsenter.u1000 \
              && rm /usr/sbin/iptables \
              && cp /usr/sbin/xtables-nft-multi /usr/sbin/iptables \
              && chmod u+s /usr/sbin/iptables; }' \
       && chmod 755 /cgi-bin/rpc

CMD ["bash", "-il"]
