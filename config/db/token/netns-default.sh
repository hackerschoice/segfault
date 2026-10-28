# Must be enabled in config/etc/sf/sf.conf or limits.conf:
# SF_USER_FW=default
iptables -A "${FORWARD_USER}" -p udp --dport 53 -m limit --limit 8/s --limit-burst 2000 -j RETURN
iptables -A "${FORWARD_USER}" -p udp --dport 53 -j DROP
iptables -A "${FORWARD_USER}" -p icmp -m limit --limit 4/s --limit-burst 2000 -j RETURN
iptables -A "${FORWARD_USER}" -p icmp -j DROP
