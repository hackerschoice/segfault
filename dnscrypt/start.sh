#! /usr/bin/env bash

[ -e /config/dnscrypt-proxy.toml ] && CFG="/config/dnscrypt-proxy.toml"
# [ -e /config/forwarding-rules.txt ] && CFG_FW="/config/forwarding-rules.txt"

[ -z "$CFG_FW" ] && CFG_FW="/opt/forwarding-rules.txt"
# [ -z "$CFG" ] && CFG="/opt/dnscrypt-proxy.toml"

cd /config
exec /usr/sbin/dnscrypt-proxy -config "$CFG"
