#! /usr/bin/env bash

## In the format of:
# HOSTS+=("adm")
# HOSTS+=("lgm")

source .env_hosts || exit

unip="${1//[^0-9.:]}"
fn="banned/ip-${unip:?}"
[ ! -f "${fn}" ] && { echo >&2 "Not found: $fn"; exit; }
rm -f "${fn:?}"

for h in "${HOSTS[@]}"; do
    ssh "${h}" "rm -f /sf/config/db/${fn}"
done
