


root: 3thZTka1Lb5yVYzTYjQaG3
# why not use nordvpn's routing?? all via tunnel

# Everything that does not come from docker shall go into normal ethernet
#iptables -t mangle -A PREROUTING ! -i docker0 -j MARK --set-mark 3
#iptables -t mangle -A PREROUTING -i docker0 -p udp --dport 53 -j MARK --set-mark 3

# Everything from _this_ host should go to ens5
iptables -t mangle -A OUTPUT -j MARK --set-mark 3
# DNS requests should go to my own RESOLVER [DNSSEC] (FIXME)
iptables -t mangle -A PREROUTING -i docker0 -p udp --dport 53 -j MARK --set-mark 3

# Incoming port 22 should go to docker:2222 and answers need to leave _not_ via VPN
iptables -t mangle -A PREROUTING -p tcp --sport 2222 -i docker0 -m conntrack --ctstate ESTABLISHED,RELATED -j MARK --set-mark 3

ip route add default via 172.31.32.1 dev ens5 table 3
ip rule add fwmark 3 table 3

# All PREROUTING packets forced to ens5 need to MASQ their source IP
iptables -t nat -A POSTROUTING -o ens5 -m mark --mark 3 -j MASQUERADE

# Stop all docker traffic unless it's marked (e.g. incoming-22, outgoing-53)
iptables -I FORWARD 1 -i docker0 -o ens5 -m mark ! --mark 3 -j DROP


#FIXME: DNSSEC (encrypted)


