# segfault.net - A Server Centre Depoyment 

This page is for server administrators and those folks who like to run their own segfault.net server centre. Running your own Segfault Server Centre allows you to offer root-servers to other users.

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
SF_BASEDIR=$(pwd) SF_SSH_PORT=2222 docker-compose up
```

Then log in to a new root server
```shell
ssh -p 2222 root@127.1 # password is 'segfault'
```
Every new SSH connection creates a ***new dedicated root server.***

Take a look at ```provision/env.example``` for a sample ```.env``` file.

# Provisioning

Provisioning turns a bare minimum Linux into a Segfault Server Centre. The provisioning script installs docker, creates a dedicated user and sets up the  ```.env``` file and thereafter executes the same steps as in "Deploy a Server Centre". If you already have docker running then you do not need this step. We use this script to turn a freshly created AWS instance into a Segfault Server Centre:

```shell
git clone https://github.com/hackerschoice/segfault.git
SF_SEED=XXX \
SF_FQDN=us.segfault.net \
SF_MAXOUT=10Mbit \
SF_NORDVPN_PRIVATE_KEY=YYY \
segfault/provision/init-ubuntu.sh
```

We use Route53 so that the user always connects to the nearest Segfault Server Centre. E.g. ```segfault.net``` will resolve to ```us.segfault.net``` if you are in the US. The ```SF_FQDN=``` is the unique name for that region.

The ```SF_SEED``` is the master seed from which many cryptographical keys are derived. We do not store the ```SF_SEED=``` in the ```.env``` file (however, this is possible but not advisable). The Server Centre won't start without the SF_SEED. A manual start is needed if the AWS instance reboots:

```
cd segfault
SF_SEED=XXX docker-compose up -d
```

Other environment variables can be set:
```
SF_SEED=             The master seed. [default=$(head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32)]
SF_HOST_USER=        The user name in root@segfault.net. [default=root]
SF_FQDN=             A unique domain name to reach the Server Centre [default=auto]
SF_MAXOUT=           Limit outgoing traffic. [default=unlimited]
SF_MAXIN=            Limit incoming traffic. [default=unlimited]
SF_HOST_PASSWORD=    The user password for root@segfault.net. [default=segfault]
SF_BASEDIR=          A location to store configuration data. [default=~ubuntu/segfault]
SF_SHMDIR=           A volatile location. [default=/dev/shm/sf-*]
SF_SSH_PORT=         The TCP port on which the Server Centre should run on [default=22]
SF_SSH_PORT_MASTER=  Move the hosting server's SSH port to this port [default=64222]
SF_DEBUG=1           Turn on debug output.
```

The Segfault Server Centre routes all outgoing traffic through at VPN (if availabe) or TOR otherwise. The following environment variables can be set to configure the VPN (optional):
```
SF_NORDVPN_PRIVATE_KEY=     NordVPN
SF_CRYPTOSTORM_             
```

The Segfault Server Centre stores data in to locations.
 1. ```segfault/config``` contains the configuration.
 1. ```segfault/data``` contains encrypted user data.

Both locations (and the SF_SEED and .env file) should be backed up. All are needed to recreate the Server Centre and all user data from scatch.


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

