FROM bubuntux/nordlynx

COPY md5-orig.txt /
RUN md5sum -c /md5-orig.txt || { echo -e "\e[1;31m@@@@ NordLYNX got updated. Might need to adjust our scripts @@@@\e[0m"; exit 255; sleep 10; }
COPY run /etc/services.d/wireguard/
COPY 10-adduser /etc/cont-init.d/
COPY vpn_wg2status.sh /sf/bin/
