#! /bin/bash

# The master can take commands from NGINX (or redis [not yet implemented])

source /sf/bin/funcs.sh || { sleep 5; exit 255; }

SOCKET="/dev/shm/master/fcgiwrap.socket"
rm -f "${SOCKET:?}"


# set -e
# WARNING: runs as root in host's pid namespace 
fcgiwrap  -s "unix:${SOCKET}" -c1 -p /cgi-bin/rpc 2>&1 &

# su -s /bin/bash -c "fcgiwrap  -s unix:/dev/shm/master/fcgiwrap.socket & disown" www-data
sleep 1
chgrp www-data "${SOCKET}"
chmod g+rwx "${SOCKET}"


# Load info for when 'rpc' is called.
arr=($(docker inspect -f '{{.Id}} {{.State.Pid}}' "sf-wg"))
[[ ${#arr[@]} -eq 0 ]] && ERREXIT 255 "Cant get sf-wg info: res=${#arr[@]}"
echo "WG_CID=\"${arr[0]}\"
WG_PID=\"${arr[1]}\"" >/dev/shm/config.txt
# echo "${SF_WG_PRIVATE}" >/dev/shm/private

exec -a '[master] sleep' sleep infinity
# sleep infinity