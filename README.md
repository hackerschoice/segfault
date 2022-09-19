# segfault.net - A Server Centre Depoyment 

This page is for server administrators and those folks who like to run their own Segfault.net Server Centre (SSC). Running your own SSC allows you to offer root-servers to other users.

If this is not what you want and you just like to get a root-shell on your own server then please go to [https://www.thc.org/segfault](http://www.thc.org/segfault) or try our demo deployment:
```shell
ssh root@segfault.net # the password is 'segfault'
```

---

## Deploy a Server Centre:
```shell
git clone --depth 1 https://github.com/hackerschoice/segfault.git && \
cd segfault && \
docker build -t sf-guest guest && \
SF_SEED="$(head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32)" && \
echo "SF_SEED=${SF_SEED}" && \
SF_BASEDIR=$(pwd) SF_SEED=${SF_SEED} SF_SSH_PORT=2222 docker-compose up
```

Then log in to a new root server
```shell
ssh -p 2222 root@127.1 # password is 'segfault'
```
Every new SSH connection creates a ***new dedicated root server.***

To stop press Ctrl-C and execute:
```
docker-compose down
```

To start execute:
```
SF_BASEDIR=$(pwd) SF_SEED=SecretFromAbove SF_SSH_PORT=2222 docker-compose up
```

Take a look at `provision/env.example` for a sample `.env` file. Configure the test of the variables in `config/etc/sf/sf.conf`.

# Provisioning

Provisioning turns a freshly created Linux (a bare minimum Installation) into a SSC. It's how we 'ready' a newly launched AWS Instance for SSC deployment. You likely dont ever need this but [we wrote it down anyway](https://github.com/hackerschoice/segfault/wiki/AWS-Deployment).

---
# BETA TESTING BETA TESTING

Please report back
1. Tools missing
1. Features needed

Some suggestions by others:
1. Allow user to share data via webserver accessible by normal Internet and TOR (.onion) [thanks 0xD1G, L]
1. Allow email access [thanks L]
1. Proxychain [thanks DrWho]
1. **PM me if you have more suggestions** 
---

SSC can be deployed in various regions using Route53 to reduce latency.

Helpful links
1. https://github.com/nicolaka/netshoot
1. https://www.linuxserver.io/ and https://github.com/just-containers/s6-overlay
1. https://jordanelver.co.uk/blog/2019/06/03/routing-docker-traffic-through-a-vpn-connection/ 
1. https://hub.docker.com/r/alexaso/dnsmasq-dnscrypt and https://github.com/crazy-max/docker-cloudflared
1. https://wiki.archlinux.org/title/EncFS
1. https://www.supertechcrew.com/wetty-browser-ssh-terminal/

VPN Providers:
1. ProtonVPN
1. NordVPN
1. https://www.cryptostorm.is/
1. https://mullvad.net/en/

Hosting providers:
1. https://www.linode.com/
1. https://1984hosting.com/

---
Telegram: https://t.me/thcorg  
Twitter: https://twitter.com/hackerschoice

