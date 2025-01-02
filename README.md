# segfault.net - A Server Centre Deployment

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
SF_BASEDIR="$(pwd)" SF_SSH_PORT=2222 sfbin/sf up
```

Take a look at `provision/env.example` for a sample `.env` file.

The limits and constraints for all root servers are configured in `config/etc/sf/sf.conf`. It is possible to relax limits per individual root server by creating a file in `config/db/db-<LID>/limits.conf`. The <LID> is the ID of the server (type `echo $SF_LID` when logged in to the server). Alternatively it is possible to get the LID from the Root Server's name: `cat config/db/hn/hn2lid-<SF_HOSTNAME>`.  

# Provisioning

Provisioning turns a freshly created Linux (a bare minimum Installation) into a SSC. It's how we 'ready' a newly launched AWS Instance for SSC deployment. You likely dont ever need this but [we wrote it down anyway](https://github.com/hackerschoice/segfault/wiki/AWS-Deployment).

# GUI

[SFUI](https://github.com/messede-degod/SF-UI) is a companion project created by [@messede-degod](https://github.com/messede-degod/SF-UI). It provides a 'Remote Desktop' (X11/Gnome) to your Root Server. It is run as a Cloud Service by the community. [Try it](https://shell.segfault.net)!

---

Join us: https://thc.org/ops
