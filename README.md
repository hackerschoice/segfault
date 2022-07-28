# segfault.net - A Server Centre Depoyment 

This page is for server administrators and those folks who like to run their own segfault.net server centre. Running your own Segfault Server Centre allows you to offer root-servers to other users.

If this is not what you want and you just like to get a root-shell on your own server then please go to [https://www.thc.org/segfault](http://www.thc.org/segfault) or try our demo deployment:
```shell
ssh root@segfault.net # the password is 'segfault'
```

---

## Deploy a Server Centre:
```shell
git clone https://github.com/hackerschoice/segfault.git && \
cd segfault && \
docker build -t sf-guest guest && \
SF_BASEDIR=$(pwd) SF_SSH_PORT=2222 docker-compose up
```

Then log in to a new root server
```shell
ssh -p 2222 root@127.1 # password is 'segfault'
```
Every new SSH connection creates a ***new dedicated root server.***

Take a look at ```provision/env.example``` for a sample ```.env``` file.

---
* JOIN US ON TELEGRAM. LET US KNOW WHAT YOU WANT AND NEED *
---

A root shell for every (creative) person. Free. Anonymous. Secure.

A new instance is spawned for every new connection. Each instance has these features:
1. Dedicated ```root server``` for every user.
1. All traffic is routed via NordVPN.
1. All DNS traffic is encrypted (DNS over HTTPS).
1. TOR pre-installed.
1. Encrypted/Persistent storage in ```/sec```. Private to the User.
1. Each User has his own ```SECRET``` to access his data.
1. No trace (beside encrypted data) after the User logs off.
1. No logs are kept.

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

Cluster can be deployed in various regions for less latency.
Misc infos:
1. https://docs.docker.com/engine/security/userns-remap/
1. On small deployments the ```OpenVPN Server``` can be the same as Server[12]. This allows to run *everything* off 1 single server.
1. AWS Fargate could be utilized by nesting the entire setup in a Docker-in-Docker (dind) configuration.

Helpful links
1. https://github.com/nicolaka/netshoot
1. https://www.linuxserver.io/ and https://github.com/just-containers/s6-overlay
1. https://jordanelver.co.uk/blog/2019/06/03/routing-docker-traffic-through-a-vpn-connection/ 
1. https://hub.docker.com/r/alexaso/dnsmasq-dnscrypt and https://github.com/crazy-max/docker-cloudflared
2. https://wiki.archlinux.org/title/EncFS
3. https://www.supertechcrew.com/wetty-browser-ssh-terminal/

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

