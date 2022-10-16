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
export SF_SEED="$(head -c 1024 /dev/urandom | tr -dc '[:alpha:]' | head -c 32)" && \
echo "SF_SEED=${SF_SEED}" && \
make
```

To start execute:
```
SF_BASEDIR=$(pwd) SF_SSH_PORT=2222 sfbin/sf up
```

Take a look at `provision/env.example` for a sample `.env` file. Configure the test of the variables in `config/etc/sf/sf.conf`.

# Provisioning

Provisioning turns a freshly created Linux (a bare minimum Installation) into a SSC. It's how we 'ready' a newly launched AWS Instance for SSC deployment. You likely dont ever need this but [we wrote it down anyway](https://github.com/hackerschoice/segfault/wiki/AWS-Deployment).

---

Telegram: https://t.me/thcorg  
Twitter: https://twitter.com/hackerschoice

