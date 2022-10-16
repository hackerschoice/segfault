Title: My Latest Article About Hello
Date: 2022-10-01 11:59
Author: MySelfMeMeMe
Tags: hacking, tutorial

## Using Pelican to generate static files

This is my latest article.

All `artciles/*.md` files are displayed here. The newest article is shown first (this one). Currently there are only 2 articles in this section. Add more `*.md` files to the `articles/` folder to display more articles.

It's great for publishing source code:
```bash
reconnect_init()
{
  [[ -z $RECONNECT ]] && return

  echo "[$(date -Iseconds)] Reconnecting in ${RECONNECT} seconds..."
  RE_EXPIRE=$(($(date +%s) + RECONNECT))
}

[[ $(sysctl net.ipv4.ip_forward -b) -ne 1 ]] && WARN "ip_forward= not set"

# Operate on Ramdisk
[[ ! -d /dev/shm/wireguard ]] && mkdir /dev/shm/wireguard

[[ -z $PROVIDER ]] && PROVIDER="CryptoStorm"
PROV="${PROVIDER,,}"
```
and much more...
