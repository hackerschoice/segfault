#! /bin/bash

# MASTER setup script

set -e
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce-cli --no-install-recommends
rm -rf /var/lib/apt/lists/*

# Fix VmBox perms
chmod 755 /cgi-bin/*.sh /cgi-bin/rpc

set +e