# iptables 'nft' needs rolling.
# FROM ubuntu:rolling
FROM sf-base


COPY ready-lg-router.sh init.sh init-wg.sh init-novpn.sh fix-network.sh /
CMD ["bash", "-il"]

