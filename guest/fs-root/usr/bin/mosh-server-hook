#! /bin/bash

# Will be renamed to mosh-server

[[ $1 != "new" ]] && exec -a mosh-server /usr/bin/mosh-server.orig "$@"

shift 1

ip=$(ip addr show eth0)
ip=${ip##*inet }
ip=${ip%%/*}
y=${ip##*.}
x=${ip%.*}
x=${x##*.}

exec -a mosh-server /usr/bin/mosh-server.orig new -p $((25000 + x*256 + y)) "$@"

